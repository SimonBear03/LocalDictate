import AVFoundation
import CoreMedia
import LocalDictateCore
import OSLog
import Speech

private let speechRecognitionLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.simonbear.localdictate",
    category: "SpeechRecognition"
)

final class AudioRecorderService: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate {
    private let captureQueue = DispatchQueue(label: "com.simonbear.localdictate.audio-capture")
    private var captureSession: AVCaptureSession?
    private var captureOutput: AVCaptureAudioDataOutput?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionState: LiveRecognitionState?
    private var analyzerSession: AnyObject?
    private var preferredCaptureAudioSettings: [String: Any]?
    private var meter = AudioLevelMeter()
    private var startedAt: Date?
    private var activeInputName = "Unknown"
    private(set) var activeRecordingURL: URL?

    var isRecording: Bool {
        captureSession?.isRunning == true
    }

    @MainActor
    func startRecording(
        inputDeviceID: String,
        locale: Locale,
        retainAudio: Bool,
        onPartialTranscript: @escaping @MainActor @Sendable (String) -> Void,
        onDebugEvent: @escaping @MainActor @Sendable (SpeechRecognitionDebugEvent) -> Void
    ) async throws -> URL? {
        guard PermissionService.speechState() == .granted else {
            throw SpeechEngineError.permissionNeeded
        }

        cleanup(removeActiveAudio: true)

        startedAt = Date()

        do {
            if #available(macOS 26.0, *) {
                do {
                    analyzerSession = try await AnalyzerRecognitionSession.start(
                        locale: locale,
                        onPartialTranscript: onPartialTranscript,
                        onDebugEvent: onDebugEvent
                    )
                    preferredCaptureAudioSettings = (analyzerSession as? AnalyzerRecognitionSession)?.captureAudioSettings
                } catch {
                    speechRecognitionLogger.warning("SpeechAnalyzer setup failed, falling back to SFSpeechRecognizer: \(error.localizedDescription, privacy: .public)")
                    try startLegacyRecognition(
                        locale: locale,
                        onPartialTranscript: onPartialTranscript,
                        onDebugEvent: onDebugEvent
                    )
                }
            } else {
                try startLegacyRecognition(
                    locale: locale,
                    onPartialTranscript: onPartialTranscript,
                    onDebugEvent: onDebugEvent
                )
            }

            try startMicrophoneCapture(inputDeviceID: inputDeviceID)
        } catch {
            recognitionTask?.cancel()
            if #available(macOS 26.0, *), let analyzerSession = analyzerSession as? AnalyzerRecognitionSession {
                analyzerSession.cancel()
            }
            cleanup(removeActiveAudio: true)
            throw error
        }

        return activeRecordingURL
    }

    @MainActor
    func stopRecording() async throws -> AudioRecordingResult? {
        if #available(macOS 26.0, *), let analyzerSession = analyzerSession as? AnalyzerRecognitionSession {
            let stoppedAt = Date()
            stopAudioCapture()
            try analyzerSession.finishAudio()
            let transcript = try await analyzerSession.waitForFinal(timeout: 12)
            let diagnostics = diagnostics(stoppedAt: stoppedAt)
            let url = activeRecordingURL
            cleanup(removeActiveAudio: false)

            return AudioRecordingResult(transcript: transcript, url: url, diagnostics: diagnostics)
        }

        guard let request = recognitionRequest, let state = recognitionState else {
            return nil
        }

        let stoppedAt = Date()
        stopAudioCapture()
        state.markAudioEnded()
        request.endAudio()
        recognitionTask?.finish()

        let transcript = try await state.waitForFinal(timeout: 12)
        let diagnostics = diagnostics(stoppedAt: stoppedAt)
        let url = activeRecordingURL
        cleanup(removeActiveAudio: false)

        return AudioRecordingResult(transcript: transcript, url: url, diagnostics: diagnostics)
    }

    @MainActor
    func discardActiveRecording() {
        recognitionTask?.cancel()
        if #available(macOS 26.0, *), let analyzerSession = analyzerSession as? AnalyzerRecognitionSession {
            analyzerSession.cancel()
        }
        stopAudioCapture()
        cleanup(removeActiveAudio: true)
    }

    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        meter.record(sampleBuffer: sampleBuffer)
        if #available(macOS 26.0, *), let analyzerSession = analyzerSession as? AnalyzerRecognitionSession {
            analyzerSession.append(sampleBuffer: sampleBuffer)
        } else {
            recognitionRequest?.appendAudioSampleBuffer(sampleBuffer)
        }
    }

    private func startLegacyRecognition(
        locale: Locale,
        onPartialTranscript: @escaping @MainActor @Sendable (String) -> Void,
        onDebugEvent: @escaping @MainActor @Sendable (SpeechRecognitionDebugEvent) -> Void
    ) throws {
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw SpeechEngineError.recognizerUnavailable
        }

        guard recognizer.supportsOnDeviceRecognition else {
            throw SpeechEngineError.noLocalRecognizer
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        if #available(macOS 13.0, *) {
            request.addsPunctuation = true
        }

        let state = LiveRecognitionState(localeIdentifier: locale.identifier)
        let task = recognizer.recognitionTask(with: request) { result, error in
            state.handle(
                result: result,
                error: error,
                onPartialTranscript: onPartialTranscript,
                onDebugEvent: onDebugEvent
            )
        }

        recognitionRequest = request
        recognitionTask = task
        recognitionState = state
    }

    private func startMicrophoneCapture(inputDeviceID: String) throws {
        guard let device = AudioInputDeviceService.device(for: inputDeviceID) else {
            throw AudioRecorderError.inputUnavailable(AudioInputDeviceService.displayName(for: inputDeviceID))
        }

        let session = AVCaptureSession()
        let input = try AVCaptureDeviceInput(device: device)
        let output = AVCaptureAudioDataOutput()
        if let preferredCaptureAudioSettings {
            output.audioSettings = preferredCaptureAudioSettings
        }

        session.beginConfiguration()
        guard session.canAddInput(input) else {
            throw AudioRecorderError.inputUnavailable(device.localizedName)
        }
        session.addInput(input)

        guard session.canAddOutput(output) else {
            throw AudioRecorderError.outputUnavailable
        }
        session.addOutput(output)
        session.commitConfiguration()

        activeInputName = device.localizedName
        meter.reset(inputDeviceName: device.localizedName)
        output.setSampleBufferDelegate(self, queue: captureQueue)

        captureSession = session
        captureOutput = output
        session.startRunning()
    }

    private func stopAudioCapture() {
        if let captureSession {
            captureSession.stopRunning()
            captureOutput?.setSampleBufferDelegate(nil, queue: nil)
            captureQueue.sync {}
        }
    }

    private func cleanup(removeActiveAudio: Bool) {
        if removeActiveAudio, let activeRecordingURL {
            try? FileManager.default.removeItem(at: activeRecordingURL)
        }

        captureSession = nil
        captureOutput = nil
        recognitionRequest = nil
        recognitionTask = nil
        recognitionState = nil
        preferredCaptureAudioSettings = nil
        if #available(macOS 26.0, *), let session = analyzerSession as? AnalyzerRecognitionSession {
            session.cancel()
        }
        analyzerSession = nil
        startedAt = nil
        activeInputName = "Unknown"
        activeRecordingURL = nil
    }

    private func diagnostics(stoppedAt: Date) -> AudioRecordingDiagnostics {
        AudioRecordingDiagnostics(
            duration: startedAt.map { stoppedAt.timeIntervalSince($0) } ?? 0,
            fileSizeBytes: activeRecordingURL.flatMap(Self.fileSize),
            peakPowerDecibels: meter.peakPowerDecibels,
            rmsPowerDecibels: meter.rmsPowerDecibels,
            formatDescription: meter.formatDescription,
            inputDeviceName: meter.inputDeviceName,
            writeErrorDescription: meter.writeErrorDescription
        )
    }

    private static func fileSize(at url: URL) -> Int64? {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return attributes?[.size] as? Int64
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
}

struct AudioRecordingResult: Sendable {
    var transcript: SpeechTranscript
    var url: URL?
    var diagnostics: AudioRecordingDiagnostics
}

struct AudioRecordingDiagnostics: Sendable {
    var duration: TimeInterval
    var fileSizeBytes: Int64?
    var peakPowerDecibels: Float
    var rmsPowerDecibels: Float
    var formatDescription: String
    var inputDeviceName: String
    var writeErrorDescription: String?

    var isProbablySilent: Bool {
        duration < 0.5 || peakPowerDecibels <= -70
    }

    var summary: String {
        let durationText = Self.durationFormatter.string(from: duration) ?? String(format: "%.1fs", duration)
        let sizeText = fileSizeBytes.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "live stream"
        return "\(durationText), \(sizeText), peak \(Self.decibelFormatter.string(for: peakPowerDecibels) ?? "\(peakPowerDecibels)") dBFS, RMS \(Self.decibelFormatter.string(for: rmsPowerDecibels) ?? "\(rmsPowerDecibels)") dBFS"
    }

    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private static let decibelFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 1
        return formatter
    }()
}

enum AudioRecorderError: LocalizedError {
    case inputUnavailable(String)
    case outputUnavailable

    var errorDescription: String? {
        switch self {
        case .inputUnavailable(let name):
            "Audio input is unavailable: \(name)."
        case .outputUnavailable:
            "Audio input setup failed."
        }
    }
}

private final class LiveRecognitionState: @unchecked Sendable {
    private let lock = NSLock()
    private let localeIdentifier: String
    private var committedText = ""
    private var currentHypothesis = ""
    private var continuation: CheckedContinuation<SpeechTranscript, Error>?
    private var completedTranscript: SpeechTranscript?
    private var completedError: Error?
    private var isCompleted = false
    private var didEndAudio = false

    init(localeIdentifier: String) {
        self.localeIdentifier = localeIdentifier
    }

    func handle(
        result: SFSpeechRecognitionResult?,
        error: Error?,
        onPartialTranscript: @escaping @MainActor @Sendable (String) -> Void,
        onDebugEvent: @escaping @MainActor @Sendable (SpeechRecognitionDebugEvent) -> Void
    ) {
        if let result {
            let transcription = result.bestTranscription
            let text = transcription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                let update = lock.withLock {
                    if result.isFinal {
                        let previousText = composedText()
                        commitFinalText(text)
                        currentHypothesis = ""
                        let outputText = composedText()
                        return TranscriptAccumulatorUpdate(
                            decision: .finalResult,
                            previousText: previousText,
                            incomingText: text,
                            outputText: outputText,
                            previousWindow: nil,
                            incomingWindow: Self.segmentWindow(for: transcription.segments),
                            outputWindow: Self.segmentWindow(for: transcription.segments)
                        )
                    }

                    let previousText = composedText()
                    currentHypothesis = text
                    return TranscriptAccumulatorUpdate(
                        decision: .partialPreview,
                        previousText: previousText,
                        incomingText: text,
                        outputText: composedText(),
                        previousWindow: nil,
                        incomingWindow: Self.segmentWindow(for: transcription.segments),
                        outputWindow: Self.segmentWindow(for: transcription.segments)
                    )
                }
                speechRecognitionLogger.debug(
                    "decision=\(update.decision.rawValue, privacy: .public) incomingChars=\(update.incomingText.count, privacy: .public) outputChars=\(update.outputText.count, privacy: .public) isFinal=\(result.isFinal, privacy: .public)"
                )
                Task { @MainActor in
                    onPartialTranscript(update.outputText)
                    onDebugEvent(SpeechRecognitionDebugEvent(update: update))
                }
            }

            let shouldComplete = lock.withLock { didEndAudio }
            if result.isFinal && shouldComplete {
                completeWithFinalOrLatest(fallbackError: SpeechEngineError.emptyTranscript)
                return
            }
        }

        if let error {
            let shouldFallback = lock.withLock { didEndAudio }
            if shouldFallback {
                completeWithFinalOrLatest(fallbackError: SpeechEngineError.recognitionFailed(error.localizedDescription))
            } else {
                complete(.failure(SpeechEngineError.recognitionFailed(error.localizedDescription)))
            }
        }
    }

    func markAudioEnded() {
        var completedTranscript: SpeechTranscript?
        lock.withLock {
            didEndAudio = true
            if !committedText.isEmpty, currentHypothesis.isEmpty {
                completedTranscript = SpeechTranscript(text: committedText, languageIdentifier: localeIdentifier)
            }
        }

        if let completedTranscript {
            complete(.success(completedTranscript))
        }
    }

    func waitForFinal(timeout: TimeInterval) async throws -> SpeechTranscript {
        try await withCheckedThrowingContinuation { continuation in
            var transcript: SpeechTranscript?
            var error: Error?

            lock.withLock {
                if isCompleted {
                    transcript = completedTranscript
                    error = completedError
                } else {
                    self.continuation = continuation
                }
            }

            if let transcript {
                continuation.resume(returning: transcript)
                return
            }

            if let error {
                continuation.resume(throwing: error)
                return
            }

            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { [weak self] in
                self?.completeWithFinalOrLatest(
                    fallbackError: SpeechEngineError.recognitionFailed("Timed out waiting for local speech recognition.")
                )
            }
        }
    }

    private func completeWithFinalOrLatest(fallbackError: Error) {
        let text = lock.withLock {
            composedText().trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if text.isEmpty {
            complete(.failure(fallbackError))
        } else {
            complete(.success(SpeechTranscript(text: text, languageIdentifier: localeIdentifier)))
        }
    }

    private func composedText() -> String {
        if currentHypothesis.isEmpty {
            return committedText
        }

        if committedText.isEmpty {
            return currentHypothesis
        }

        if currentHypothesis == committedText ||
            currentHypothesis.hasPrefix(committedText) ||
            committedText.hasSuffix(currentHypothesis) {
            return currentHypothesis.count >= committedText.count ? currentHypothesis : committedText
        }

        return Self.join(committedText, currentHypothesis)
    }

    private func commitFinalText(_ text: String) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        if committedText.isEmpty {
            committedText = text
            return
        }

        if committedText == text || committedText.hasSuffix(text) {
            return
        }

        if text.hasPrefix(committedText) {
            committedText = text
            return
        }

        if let merged = Self.mergeOverlap(committedText, text) {
            committedText = merged
            return
        }

        committedText = Self.join(committedText, text)
    }

    private static func join(_ lhs: String, _ rhs: String) -> String {
        let lhs = lhs.trimmingCharacters(in: .whitespacesAndNewlines)
        let rhs = rhs.trimmingCharacters(in: .whitespacesAndNewlines)

        if lhs.isEmpty { return rhs }
        if rhs.isEmpty { return lhs }

        return "\(lhs) \(rhs)"
    }

    private static func mergeOverlap(_ lhs: String, _ rhs: String) -> String? {
        let maxLength = min(lhs.count, rhs.count)
        guard maxLength >= 12 else { return nil }

        for length in stride(from: maxLength, through: 12, by: -1) {
            let lhsStart = lhs.index(lhs.endIndex, offsetBy: -length)
            let rhsEnd = rhs.index(rhs.startIndex, offsetBy: length)
            if lhs[lhsStart...] == rhs[..<rhsEnd] {
                return lhs + rhs[rhsEnd...]
            }
        }

        return nil
    }

    private static func segmentWindow(for segments: [SFTranscriptionSegment]) -> TranscriptSegmentWindow? {
        guard let first = segments.first else {
            return nil
        }

        let start = first.timestamp
        let end = segments.reduce(start) { partialResult, segment in
            max(partialResult, segment.timestamp + segment.duration)
        }
        return TranscriptSegmentWindow(start: start, end: end)
    }

    private func complete(_ result: Result<SpeechTranscript, Error>) {
        var continuationToResume: CheckedContinuation<SpeechTranscript, Error>?

        lock.withLock {
            guard !isCompleted else { return }
            isCompleted = true
            continuationToResume = continuation
            continuation = nil

            switch result {
            case .success(let transcript):
                completedTranscript = transcript
            case .failure(let error):
                completedError = error
            }
        }

        guard let continuationToResume else { return }

        switch result {
        case .success(let transcript):
            continuationToResume.resume(returning: transcript)
        case .failure(let error):
            continuationToResume.resume(throwing: error)
        }
    }
}

@available(macOS 26.0, *)
private final class AnalyzerRecognitionSession: @unchecked Sendable {
    private let lock = NSLock()
    private let localeIdentifier: String
    private let transcriber: DictationTranscriber
    private let analyzer: SpeechAnalyzer
    private let inputContinuation: AsyncThrowingStream<AnalyzerInput, Error>.Continuation
    private let onPartialTranscript: @MainActor @Sendable (String) -> Void
    private let onDebugEvent: @MainActor @Sendable (SpeechRecognitionDebugEvent) -> Void
    private var buffer = ProgressiveTranscriptBuffer()
    private var analysisTask: Task<Void, Never>?
    private var resultsTask: Task<Void, Never>?
    private var continuation: CheckedContinuation<SpeechTranscript, Error>?
    private var completedTranscript: SpeechTranscript?
    private var completedError: Error?
    private var isCompleted = false
    private var didEndAudio = false
    let captureAudioSettings: [String: Any]?

    private init(
        localeIdentifier: String,
        transcriber: DictationTranscriber,
        analyzer: SpeechAnalyzer,
        inputContinuation: AsyncThrowingStream<AnalyzerInput, Error>.Continuation,
        captureAudioSettings: [String: Any]?,
        onPartialTranscript: @escaping @MainActor @Sendable (String) -> Void,
        onDebugEvent: @escaping @MainActor @Sendable (SpeechRecognitionDebugEvent) -> Void
    ) {
        self.localeIdentifier = localeIdentifier
        self.transcriber = transcriber
        self.analyzer = analyzer
        self.inputContinuation = inputContinuation
        self.captureAudioSettings = captureAudioSettings
        self.onPartialTranscript = onPartialTranscript
        self.onDebugEvent = onDebugEvent
    }

    static func start(
        locale: Locale,
        onPartialTranscript: @escaping @MainActor @Sendable (String) -> Void,
        onDebugEvent: @escaping @MainActor @Sendable (SpeechRecognitionDebugEvent) -> Void
    ) async throws -> AnalyzerRecognitionSession {
        guard let supportedLocale = await DictationTranscriber.supportedLocale(equivalentTo: locale) else {
            throw SpeechEngineError.noLocalRecognizer
        }

        let transcriber = DictationTranscriber(
            locale: supportedLocale,
            contentHints: [],
            transcriptionOptions: [.punctuation],
            reportingOptions: [.volatileResults, .frequentFinalization],
            attributeOptions: [.audioTimeRange, .transcriptionConfidence]
        )
        let modules: [any SpeechModule] = [transcriber]

        let assetStatus = await AssetInventory.status(forModules: modules)
        guard assetStatus != .unsupported else {
            throw SpeechEngineError.noLocalRecognizer
        }
        if assetStatus != .installed, let installationRequest = try await AssetInventory.assetInstallationRequest(supporting: modules) {
            try await installationRequest.downloadAndInstall()
        }

        let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: modules)
        let analyzer = SpeechAnalyzer(modules: modules)
        try await analyzer.prepareToAnalyze(in: analyzerFormat)

        let (inputStream, inputContinuation) = AsyncThrowingStream<AnalyzerInput, Error>.makeStream(of: AnalyzerInput.self)
        let session = AnalyzerRecognitionSession(
            localeIdentifier: supportedLocale.identifier,
            transcriber: transcriber,
            analyzer: analyzer,
            inputContinuation: inputContinuation,
            captureAudioSettings: analyzerFormat.map(Self.captureAudioSettings),
            onPartialTranscript: onPartialTranscript,
            onDebugEvent: onDebugEvent
        )
        session.startTasks(inputStream: inputStream)
        return session
    }

    func append(sampleBuffer: CMSampleBuffer) {
        let shouldAcceptAudio = lock.withLock { !didEndAudio && !isCompleted }
        guard shouldAcceptAudio, let pcmBuffer = sampleBuffer.localDictatePCMBuffer() else {
            return
        }

        inputContinuation.yield(AnalyzerInput(buffer: pcmBuffer))
    }

    func finishAudio() throws {
        let shouldFinish = lock.withLock {
            guard !didEndAudio else { return false }
            didEndAudio = true
            return true
        }
        guard shouldFinish else { return }

        inputContinuation.finish()
    }

    func waitForFinal(timeout: TimeInterval) async throws -> SpeechTranscript {
        try await withCheckedThrowingContinuation { continuation in
            var transcript: SpeechTranscript?
            var error: Error?

            lock.withLock {
                if isCompleted {
                    transcript = completedTranscript
                    error = completedError
                } else {
                    self.continuation = continuation
                }
            }

            if let transcript {
                continuation.resume(returning: transcript)
                return
            }

            if let error {
                continuation.resume(throwing: error)
                return
            }

            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { [weak self] in
                self?.completeWithFinalOrLatest(
                    fallbackError: SpeechEngineError.recognitionFailed("Timed out waiting for local speech recognition.")
                )
            }
        }
    }

    func cancel() {
        analysisTask?.cancel()
        resultsTask?.cancel()
        inputContinuation.finish()
        Task {
            await analyzer.cancelAndFinishNow()
        }
    }

    private func startTasks(inputStream: AsyncThrowingStream<AnalyzerInput, Error>) {
        resultsTask = Task { [weak self, transcriber] in
            do {
                for try await result in transcriber.results {
                    self?.handle(result: result)
                }
                self?.completeWithFinalOrLatest(fallbackError: SpeechEngineError.emptyTranscript)
            } catch {
                self?.complete(.failure(SpeechEngineError.recognitionFailed(error.localDictateDiagnosticDescription)))
            }
        }

        analysisTask = Task { [weak self, analyzer] in
            do {
                let lastSampleTime = try await analyzer.analyzeSequence(inputStream)
                if let lastSampleTime {
                    try await analyzer.finalizeAndFinish(through: lastSampleTime)
                } else {
                    await analyzer.cancelAndFinishNow()
                }
            } catch {
                self?.complete(.failure(SpeechEngineError.recognitionFailed(error.localDictateDiagnosticDescription)))
            }
        }
    }

    private func handle(result: DictationTranscriber.Result) {
        let incomingText = String(result.text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !incomingText.isEmpty else { return }

        let incomingWindow = Self.window(for: result.range)
        let update = lock.withLock {
            buffer.updateDetailed(
                text: incomingText,
                window: incomingWindow,
                isFinal: result.isFinal
            )
        }

        speechRecognitionLogger.debug(
            "engine=analyzer decision=\(update.decision.rawValue, privacy: .public) incomingChars=\(update.incomingText.count, privacy: .public) outputChars=\(update.outputText.count, privacy: .public) isFinal=\(result.isFinal, privacy: .public)"
        )

        Task { @MainActor in
            onPartialTranscript(update.outputText)
            onDebugEvent(SpeechRecognitionDebugEvent(update: update))
        }
    }

    private func completeWithFinalOrLatest(fallbackError: Error) {
        let text = lock.withLock {
            buffer.text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if text.isEmpty {
            complete(.failure(fallbackError))
        } else {
            complete(.success(SpeechTranscript(text: text, languageIdentifier: localeIdentifier)))
        }
    }

    private func complete(_ result: Result<SpeechTranscript, Error>) {
        var continuationToResume: CheckedContinuation<SpeechTranscript, Error>?

        lock.withLock {
            guard !isCompleted else { return }
            isCompleted = true
            continuationToResume = continuation
            continuation = nil

            switch result {
            case .success(let transcript):
                completedTranscript = transcript
            case .failure(let error):
                completedError = error
            }
        }

        guard let continuationToResume else { return }

        switch result {
        case .success(let transcript):
            continuationToResume.resume(returning: transcript)
        case .failure(let error):
            continuationToResume.resume(throwing: error)
        }
    }

    private static func window(for range: CMTimeRange) -> TranscriptSegmentWindow {
        let start = seconds(for: range.start) ?? 0
        let end = seconds(for: CMTimeRangeGetEnd(range)) ?? start
        return TranscriptSegmentWindow(start: start, end: max(start, end))
    }

    private static func seconds(for time: CMTime) -> TimeInterval? {
        guard time.isValid, time.isNumeric else {
            return nil
        }
        let seconds = CMTimeGetSeconds(time)
        return seconds.isFinite ? seconds : nil
    }

    private static func captureAudioSettings(for format: AVAudioFormat) -> [String: Any] {
        let description = format.streamDescription.pointee
        let flags = description.mFormatFlags
        return [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: description.mSampleRate,
            AVNumberOfChannelsKey: Int(description.mChannelsPerFrame),
            AVLinearPCMBitDepthKey: Int(description.mBitsPerChannel),
            AVLinearPCMIsFloatKey: flags & kAudioFormatFlagIsFloat != 0,
            AVLinearPCMIsBigEndianKey: flags & kAudioFormatFlagIsBigEndian != 0,
            AVLinearPCMIsNonInterleaved: flags & kAudioFormatFlagIsNonInterleaved != 0
        ]
    }
}

private final class AudioLevelMeter: @unchecked Sendable {
    private let lock = NSLock()
    private var peak: Float = 0
    private var sumSquares: Double = 0
    private var sampleCount: Int = 0
    private var format: String = "Unknown"
    private var inputName: String = "Unknown"
    private var writeError: String?

    var peakPowerDecibels: Float {
        lock.withLock { Self.decibels(forLinearAmplitude: peak) }
    }

    var rmsPowerDecibels: Float {
        lock.withLock {
            guard sampleCount > 0 else { return -120 }
            return Self.decibels(forLinearAmplitude: Float(sqrt(sumSquares / Double(sampleCount))))
        }
    }

    var formatDescription: String {
        lock.withLock { format }
    }

    var inputDeviceName: String {
        lock.withLock { inputName }
    }

    var writeErrorDescription: String? {
        lock.withLock { writeError }
    }

    func reset(inputDeviceName: String) {
        lock.withLock {
            peak = 0
            sumSquares = 0
            sampleCount = 0
            format = "Unknown"
            inputName = inputDeviceName
            writeError = nil
        }
    }

    func record(pcmBuffer: AVAudioPCMBuffer) {
        let channelCount = Int(pcmBuffer.format.channelCount)
        let frameLength = Int(pcmBuffer.frameLength)
        guard frameLength > 0 else { return }

        var localPeak: Float = 0
        var localSumSquares = 0.0
        var localSamples = 0

        if let floatChannelData = pcmBuffer.floatChannelData {
            for channel in 0..<channelCount {
                recordSamples(
                    floatChannelData[channel],
                    count: frameLength,
                    peak: &localPeak,
                    sumSquares: &localSumSquares,
                    sampleCount: &localSamples
                )
            }
        } else if let int16ChannelData = pcmBuffer.int16ChannelData {
            for channel in 0..<channelCount {
                recordSamples(
                    int16ChannelData[channel],
                    count: frameLength,
                    scale: Float(Int16.max),
                    peak: &localPeak,
                    sumSquares: &localSumSquares,
                    sampleCount: &localSamples
                )
            }
        } else if let int32ChannelData = pcmBuffer.int32ChannelData {
            for channel in 0..<channelCount {
                recordSamples(
                    int32ChannelData[channel],
                    count: frameLength,
                    scale: Float(Int32.max),
                    peak: &localPeak,
                    sumSquares: &localSumSquares,
                    sampleCount: &localSamples
                )
            }
        }

        let formatDescriptionText = "\(Int(pcmBuffer.format.sampleRate)) Hz, \(pcmBuffer.format.channelCount) ch, \(pcmBuffer.format.streamDescription.pointee.mBitsPerChannel)-bit"
        lock.withLock {
            peak = max(peak, localPeak)
            sumSquares += localSumSquares
            sampleCount += localSamples
            format = formatDescriptionText
        }
    }

    func record(sampleBuffer: CMSampleBuffer) {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              let streamDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) else {
            return
        }

        var audioBufferListSize = 0
        let sizeStatus = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: &audioBufferListSize,
            bufferListOut: nil,
            bufferListSize: 0,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: 0,
            blockBufferOut: nil
        )
        guard sizeStatus == noErr, audioBufferListSize > 0 else { return }

        let rawBufferList = UnsafeMutableRawPointer.allocate(
            byteCount: audioBufferListSize,
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { rawBufferList.deallocate() }

        var blockBuffer: CMBlockBuffer?
        let listStatus = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: rawBufferList.assumingMemoryBound(to: AudioBufferList.self),
            bufferListSize: audioBufferListSize,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        guard listStatus == noErr else { return }

        var localPeak: Float = 0
        var localSumSquares = 0.0
        var localSamples = 0
        let flags = streamDescription.pointee.mFormatFlags
        let bitsPerChannel = streamDescription.pointee.mBitsPerChannel

        for audioBuffer in UnsafeMutableAudioBufferListPointer(rawBufferList.assumingMemoryBound(to: AudioBufferList.self)) {
            guard let data = audioBuffer.mData else { continue }
            let byteSize = Int(audioBuffer.mDataByteSize)

            if flags & kAudioFormatFlagIsFloat != 0, bitsPerChannel == 32 {
                let samples = data.assumingMemoryBound(to: Float.self)
                recordSamples(samples, count: byteSize / MemoryLayout<Float>.size, peak: &localPeak, sumSquares: &localSumSquares, sampleCount: &localSamples)
            } else if bitsPerChannel == 16 {
                let samples = data.assumingMemoryBound(to: Int16.self)
                recordSamples(samples, count: byteSize / MemoryLayout<Int16>.size, scale: Float(Int16.max), peak: &localPeak, sumSquares: &localSumSquares, sampleCount: &localSamples)
            } else if bitsPerChannel == 32 {
                let samples = data.assumingMemoryBound(to: Int32.self)
                recordSamples(samples, count: byteSize / MemoryLayout<Int32>.size, scale: Float(Int32.max), peak: &localPeak, sumSquares: &localSumSquares, sampleCount: &localSamples)
            }
        }

        let formatDescriptionText = "\(Int(streamDescription.pointee.mSampleRate)) Hz, \(streamDescription.pointee.mChannelsPerFrame) ch, \(bitsPerChannel)-bit"
        lock.withLock {
            peak = max(peak, localPeak)
            sumSquares += localSumSquares
            sampleCount += localSamples
            format = formatDescriptionText
        }
    }

    private func recordSamples(
        _ samples: UnsafePointer<Float>,
        count: Int,
        peak: inout Float,
        sumSquares: inout Double,
        sampleCount: inout Int
    ) {
        for index in 0..<count {
            let value = abs(samples[index])
            peak = max(peak, value)
            sumSquares += Double(value * value)
            sampleCount += 1
        }
    }

    private func recordSamples<T: BinaryInteger>(
        _ samples: UnsafePointer<T>,
        count: Int,
        scale: Float,
        peak: inout Float,
        sumSquares: inout Double,
        sampleCount: inout Int
    ) {
        for index in 0..<count {
            let value = abs(Float(Int64(samples[index])) / scale)
            peak = max(peak, value)
            sumSquares += Double(value * value)
            sampleCount += 1
        }
    }

    func recordWriteError(_ error: Error) {
        lock.withLock {
            writeError = error.localDictateDiagnosticDescription
        }
    }

    private static func decibels(forLinearAmplitude value: Float) -> Float {
        guard value > 0 else { return -120 }
        return max(-120, 20 * log10(value))
    }
}

private extension CMSampleBuffer {
    func localDictatePCMBuffer() -> AVAudioPCMBuffer? {
        guard let formatDescription = CMSampleBufferGetFormatDescription(self),
              let streamDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription),
              streamDescription.pointee.mFormatID == kAudioFormatLinearPCM,
              let format = AVAudioFormat(streamDescription: streamDescription) else {
            return nil
        }

        let frameCount = CMSampleBufferGetNumSamples(self)
        guard frameCount > 0,
              let pcmBuffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: AVAudioFrameCount(frameCount)
              ) else {
            return nil
        }
        pcmBuffer.frameLength = AVAudioFrameCount(frameCount)

        var audioBufferListSize = 0
        let sizeStatus = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            self,
            bufferListSizeNeededOut: &audioBufferListSize,
            bufferListOut: nil,
            bufferListSize: 0,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: 0,
            blockBufferOut: nil
        )
        guard sizeStatus == noErr, audioBufferListSize > 0 else {
            return nil
        }

        let rawBufferList = UnsafeMutableRawPointer.allocate(
            byteCount: audioBufferListSize,
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { rawBufferList.deallocate() }

        var blockBuffer: CMBlockBuffer?
        let listStatus = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            self,
            bufferListSizeNeededOut: nil,
            bufferListOut: rawBufferList.assumingMemoryBound(to: AudioBufferList.self),
            bufferListSize: audioBufferListSize,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        guard listStatus == noErr else {
            return nil
        }

        let sourceBuffers = UnsafeMutableAudioBufferListPointer(rawBufferList.assumingMemoryBound(to: AudioBufferList.self))
        let destinationBuffers = UnsafeMutableAudioBufferListPointer(pcmBuffer.mutableAudioBufferList)
        let count = min(sourceBuffers.count, destinationBuffers.count)
        guard count > 0 else {
            return nil
        }

        for index in 0..<count {
            guard let sourceData = sourceBuffers[index].mData,
                  let destinationData = destinationBuffers[index].mData else {
                continue
            }
            let byteCount = min(
                Int(sourceBuffers[index].mDataByteSize),
                Int(destinationBuffers[index].mDataByteSize)
            )
            memcpy(destinationData, sourceData, byteCount)
            destinationBuffers[index].mDataByteSize = UInt32(byteCount)
        }

        return pcmBuffer
    }
}

private extension Error {
    var localDictateDiagnosticDescription: String {
        let nsError = self as NSError
        var parts = [localizedDescription, "\(nsError.domain) \(nsError.code)"]

        if let reason = nsError.localizedFailureReason, !reason.isEmpty {
            parts.append(reason)
        }

        if let recovery = nsError.localizedRecoverySuggestion, !recovery.isEmpty {
            parts.append(recovery)
        }

        return parts.joined(separator: " | ")
    }
}
