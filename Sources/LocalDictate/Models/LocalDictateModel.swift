import Foundation
import LocalDictateCore

@MainActor
final class LocalDictateModel: ObservableObject {
    @Published var status: DictationStatus = .idle
    @Published var permissions = PermissionSnapshot()
    @Published var speechAvailability: EngineAvailability = .unknown
    @Published var cleanupAvailability: EngineAvailability = .unknown
    @Published var liveTranscript = ""
    @Published var cleanedText = ""
    @Published var speechDebugEvents: [SpeechRecognitionDebugEvent] = []
    @Published var latestError: String?
    @Published var activeAudioURL: URL?
    @Published var lastAudioDiagnostics: AudioRecordingDiagnostics?
    @Published var lastInsertionDiagnostics: InsertionDiagnostics?
    @Published var audioInputDevices: [AudioInputDeviceChoice] = [.systemDefault]
    @Published var selectedSidebarSection: SidebarSection? = .history
    @Published var hotkeyDescription = "⌘D"
    @Published var hotkeyError: String?
    @Published var permissionNotice: String?
    @Published var selectedTemplateID: UUID {
        didSet { defaults.set(selectedTemplateID.uuidString, forKey: DefaultsKey.selectedTemplateID) }
    }
    @Published private(set) var insertionMode: InsertionMode = .autoPaste
    @Published var audioRetention: AudioRetention {
        didSet { defaults.set(audioRetention.rawValue, forKey: DefaultsKey.audioRetention) }
    }
    @Published var selectedAudioInputDeviceID: String {
        didSet {
            defaults.set(selectedAudioInputDeviceID, forKey: DefaultsKey.selectedAudioInputDeviceID)
            refreshAudioInputDevices()
        }
    }
    @Published var selectedLocaleIdentifier: String {
        didSet { defaults.set(selectedLocaleIdentifier, forKey: DefaultsKey.selectedLocaleIdentifier) }
    }

    let historyStore = HistoryStore()
    let templateStore = TemplateStore()
    let localAPIService = LocalAPIService()

    private let recorder = AudioRecorderService()
    private let speechEngine: SpeechEngine = AppleSpeechEngine()
    private let cleanupService: CleanupService = FoundationModelCleanupService()
    private let insertionService = InsertionService()
    private let hotkeyService = HotkeyService()
    private let defaults: UserDefaults
    private var didLaunch = false
    private var didOfferAccessibilityForCurrentRecording = false

    var selectedTemplate: CleanupTemplate {
        templateStore.template(id: selectedTemplateID)
    }

    var selectedLocale: Locale {
        Locale(identifier: selectedLocaleIdentifier)
    }

    var latestText: String {
        DictationTextSelection.preferredText(rawTranscript: liveTranscript, cleanedText: cleanedText)
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let templateString = defaults.string(forKey: DefaultsKey.selectedTemplateID)
        selectedTemplateID = templateString.flatMap(UUID.init(uuidString:)) ?? CleanupTemplate.cleanDictationID
        let retentionString = defaults.string(forKey: DefaultsKey.audioRetention)
        audioRetention = retentionString.flatMap(AudioRetention.init(rawValue:)) ?? .off
        selectedAudioInputDeviceID = defaults.string(forKey: DefaultsKey.selectedAudioInputDeviceID) ?? AudioInputDeviceChoice.systemDefaultID
        selectedLocaleIdentifier = defaults.string(forKey: DefaultsKey.selectedLocaleIdentifier) ?? Locale.current.identifier
        audioInputDevices = AudioInputDeviceService.choices(selectedID: selectedAudioInputDeviceID)
    }

    func launch() {
        guard !didLaunch else { return }
        didLaunch = true
        historyStore.load()
        templateStore.load()
        registerGlobalHotkey()
        Task {
            await refreshSystemState()
        }
    }

    func refreshSystemState() async {
        permissions = PermissionService.snapshot()
        refreshAudioInputDevices()
        speechAvailability = await speechEngine.availability(locale: selectedLocale)
        cleanupAvailability = cleanupService.availability()
    }

    func refreshAudioInputDevices() {
        audioInputDevices = AudioInputDeviceService.choices(selectedID: selectedAudioInputDeviceID)
    }

    func requestMicrophonePermission() {
        Task {
            _ = await PermissionService.requestMicrophone()
            permissionNotice = nil
            await refreshSystemState()
        }
    }

    func requestSpeechPermission() {
        Task {
            _ = await PermissionService.requestSpeech()
            permissionNotice = nil
            await refreshSystemState()
        }
    }

    @discardableResult
    func requestAccessibility() -> PermissionState {
        let state = PermissionService.requestAccessibilityPrompt()
        permissions = PermissionService.snapshot()

        guard state != .granted else {
            permissionNotice = nil
            return state
        }

        let bundleName = (Bundle.main.bundlePath as NSString).lastPathComponent
        permissionNotice = "Enable Accessibility for this exact app copy (\(bundleName)) at Privacy & Security > Accessibility. If a duplicate entry exists, remove old copies and keep only this one."
        Task { @MainActor in
            if PermissionService.confirmOpenAccessibilitySettings() {
                PermissionService.openAccessibilitySettings()
            }
        }
        return state
    }

    func toggleRecording() {
        if status == .listening {
            stopRecording()
        } else {
            startRecording()
        }
    }

    func registerGlobalHotkey() {
        do {
            try hotkeyService.registerCommandD { [weak self] in
                self?.toggleRecording()
            }
            hotkeyDescription = "⌘D"
            hotkeyError = nil
        } catch {
            hotkeyError = error.localizedDescription
        }
    }

    func startRecording() {
        latestError = nil
        didOfferAccessibilityForCurrentRecording = false

        Task { @MainActor in
            let permissionSetup = await ensureRecordingPermissions()
            guard permissionSetup.allGranted else {
                return
            }

            guard await ensureAccessibilityForAutoPasteIfNeeded() else {
                return
            }

            if permissionSetup.permissionsWereRequested {
                status = .error
                latestError = "Permissions were updated. Press ⌘D again to start recording."
                await refreshSystemState()
                return
            }

            liveTranscript = ""
            cleanedText = ""
            speechDebugEvents.removeAll()

            do {
                activeAudioURL = try await recorder.startRecording(
                    inputDeviceID: selectedAudioInputDeviceID,
                    locale: selectedLocale,
                    retainAudio: audioRetention == .manualDelete
                ) { [weak self] text in
                    self?.liveTranscript = text
                } onDebugEvent: { [weak self] event in
                    self?.appendSpeechDebugEvent(event)
                }
                status = .listening
            } catch {
                status = .error
                latestError = error.localizedDescription
                await refreshSystemState()
            }
        }
    }

    func stopRecording() {
        guard status == .listening else { return }
        status = .transcribing
        Task {
            do {
                guard let recording = try await recorder.stopRecording() else {
                    status = .error
                    latestError = "No active recording was found."
                    return
                }

                activeAudioURL = recording.url
                lastAudioDiagnostics = recording.diagnostics

                if let writeError = recording.diagnostics.writeErrorDescription {
                    latestError = "Audio was transcribed, but saving the optional audio copy failed: \(writeError)"
                }

                guard !recording.diagnostics.isProbablySilent else {
                    status = .error
                    latestError = "The recording appears silent (\(recording.diagnostics.summary)). Check the Mac input device and microphone level."
                    return
                }

                await processRecording(recording)
            } catch {
                status = .error
                latestError = error.localizedDescription
                await refreshSystemState()
            }
        }
    }

    func cancelRecording() {
        recorder.discardActiveRecording()
        activeAudioURL = nil
        status = .idle
    }

    func insertLatest() {
        do {
            applyInsertionOutcome(try insertionService.insertOrCopy(latestText, mode: insertionMode))
        } catch {
            latestError = error.localizedDescription
            status = .error
        }
    }

    func runSampleCleanup() {
        liveTranscript = "this is a local dictate test please clean it up and make it useful"
        status = .cleaning
        Task {
            do {
                cleanedText = try await cleanupService.clean(text: liveTranscript, template: selectedTemplate)
                status = .ready
            } catch {
                cleanedText = ""
                latestError = "Cleanup failed. Raw transcript is ready: \(error.localizedDescription)"
                status = .ready
            }
        }
    }

    private func processRecording(_ recording: AudioRecordingResult) async {
        let transcript = recording.transcript
        liveTranscript = transcript.text

        let shouldKeepAudio = audioRetention == .manualDelete && recording.url != nil
        if !shouldKeepAudio, let url = recording.url {
            try? FileManager.default.removeItem(at: url)
        }

        status = .cleaning
        var cleanupWarning: String?
        let cleaned: String
        do {
            cleaned = try await cleanupService.clean(text: transcript.text, template: selectedTemplate)
            cleanedText = cleaned
        } catch {
            cleaned = ""
            cleanedText = ""
            cleanupWarning = "Cleanup failed. Raw transcript is ready: \(error.localizedDescription)"
        }

        let record = DictationRecord(
            targetAppName: TargetAppService.frontmostAppName(),
            rawTranscript: transcript.text,
            cleanedText: cleaned,
            templateID: selectedTemplate.id,
            templateName: selectedTemplate.name,
            languageIdentifier: transcript.languageIdentifier,
            audioFileName: shouldKeepAudio ? recording.url?.lastPathComponent : nil
        )
        historyStore.add(record)

        do {
            let insertionText = DictationTextSelection.preferredText(rawTranscript: transcript.text, cleanedText: cleaned)
            applyInsertionOutcome(
                try insertionService.insertOrCopy(insertionText, mode: insertionMode),
                fallbackWarning: cleanupWarning
            )
        } catch {
            status = .error
            latestError = error.localizedDescription
        }

        await refreshSystemState()
    }

    private func applyInsertionOutcome(_ outcome: InsertionOutcome, fallbackWarning: String? = nil) {
        lastInsertionDiagnostics = outcome.diagnostics

        switch outcome.result {
        case .empty:
            status = .ready
            latestError = fallbackWarning
        case .copied:
            latestError = fallbackWarning
            status = .ready
        case .pasted:
            latestError = fallbackWarning
            status = .inserted
        case .copiedAccessibilityMissing:
            let accessibilityState = if didOfferAccessibilityForCurrentRecording {
                PermissionService.accessibilityState()
            } else {
                requestAccessibility()
            }
            latestError = if accessibilityState == .granted {
                "Accessibility permission is enabled. Text was copied this time; the next dictation can auto-paste."
            } else {
                "Enable Accessibility permission for automatic paste. Text is ready in LocalDictate."
            }
            status = .ready
        case .noEditableTextField:
            latestError = "No editable text field is focused. Text is ready in LocalDictate."
            status = .ready
        }
    }

    private func ensureAccessibilityForAutoPasteIfNeeded() async -> Bool {
        guard insertionMode == .autoPaste else {
            didOfferAccessibilityForCurrentRecording = false
            return true
        }

        guard PermissionService.accessibilityState() != .granted else {
            didOfferAccessibilityForCurrentRecording = false
            return true
        }

        didOfferAccessibilityForCurrentRecording = true
        _ = requestAccessibility()
                status = .error
                latestError = "Accessibility permission updated. Press ⌘D again to start recording."
                await refreshSystemState()
                return false
            }

    private func ensureRecordingPermissions() async -> (allGranted: Bool, permissionsWereRequested: Bool) {
        let microphoneResult = await resolveMicrophonePermission()
        let speechResult = await resolveSpeechPermission()
        let permissionsWereRequested = microphoneResult.requested || speechResult.requested

        guard microphoneResult.state == .granted else {
            status = .error
            latestError = permissionError(
                permissionName: "Microphone",
                state: microphoneResult.state,
                settingsPath: "System Settings > Privacy & Security > Microphone"
            )
            await refreshSystemState()
            return (allGranted: false, permissionsWereRequested: permissionsWereRequested)
        }

        guard speechResult.state == .granted else {
            status = .error
            latestError = permissionError(
                permissionName: "Speech Recognition",
                state: speechResult.state,
                settingsPath: "System Settings > Privacy & Security > Speech Recognition"
            )
            await refreshSystemState()
            return (allGranted: false, permissionsWereRequested: permissionsWereRequested)
        }

        await refreshSystemState()
        return (allGranted: true, permissionsWereRequested: permissionsWereRequested)
    }

    private func resolveMicrophonePermission() async -> (state: PermissionState, requested: Bool) {
        let state = PermissionService.microphoneState()
        guard state == .notDetermined else {
            return (state, false)
        }

        return (await PermissionService.requestMicrophone(), true)
    }

    private func resolveSpeechPermission() async -> (state: PermissionState, requested: Bool) {
        let state = PermissionService.speechState()
        guard state == .notDetermined else {
            return (state, false)
        }

        return (await PermissionService.requestSpeech(), true)
    }

    private func permissionError(permissionName: String, state: PermissionState, settingsPath: String) -> String {
        switch state {
        case .denied:
            "\(permissionName) permission was denied. Enable it in \(settingsPath)."
        case .restricted:
            "\(permissionName) permission is restricted by macOS or device policy."
        case .notDetermined:
            "\(permissionName) permission is required before recording can start."
        case .unknown:
            "\(permissionName) permission state is unknown. Check \(settingsPath)."
        case .granted:
            "\(permissionName) permission is granted."
        }
    }

    private func appendSpeechDebugEvent(_ event: SpeechRecognitionDebugEvent) {
        speechDebugEvents.insert(event, at: 0)
        if speechDebugEvents.count > 80 {
            speechDebugEvents.removeLast(speechDebugEvents.count - 80)
        }
    }
}

private enum DefaultsKey {
    static let selectedTemplateID = "selectedTemplateID"
    static let audioRetention = "audioRetention"
    static let selectedAudioInputDeviceID = "selectedAudioInputDeviceID"
    static let selectedLocaleIdentifier = "selectedLocaleIdentifier"
}
