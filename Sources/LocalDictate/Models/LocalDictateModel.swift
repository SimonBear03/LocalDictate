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
    @Published var latestError: String?
    @Published var activeAudioURL: URL?
    @Published var selectedTemplateID: UUID {
        didSet { defaults.set(selectedTemplateID.uuidString, forKey: DefaultsKey.selectedTemplateID) }
    }
    @Published var insertionMode: InsertionMode {
        didSet { defaults.set(insertionMode.rawValue, forKey: DefaultsKey.insertionMode) }
    }
    @Published var audioRetention: AudioRetention {
        didSet { defaults.set(audioRetention.rawValue, forKey: DefaultsKey.audioRetention) }
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
    private let defaults: UserDefaults

    var selectedTemplate: CleanupTemplate {
        templateStore.template(id: selectedTemplateID)
    }

    var selectedLocale: Locale {
        Locale(identifier: selectedLocaleIdentifier)
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let templateString = defaults.string(forKey: DefaultsKey.selectedTemplateID)
        selectedTemplateID = templateString.flatMap(UUID.init(uuidString:)) ?? CleanupTemplate.cleanDictationID
        let insertionString = defaults.string(forKey: DefaultsKey.insertionMode)
        insertionMode = insertionString.flatMap(InsertionMode.init(rawValue:)) ?? .copyOnly
        let retentionString = defaults.string(forKey: DefaultsKey.audioRetention)
        audioRetention = retentionString.flatMap(AudioRetention.init(rawValue:)) ?? .off
        selectedLocaleIdentifier = defaults.string(forKey: DefaultsKey.selectedLocaleIdentifier) ?? Locale.current.identifier
    }

    func launch() {
        historyStore.load()
        templateStore.load()
        Task {
            await refreshSystemState()
        }
    }

    func refreshSystemState() async {
        permissions = PermissionService.snapshot()
        speechAvailability = await speechEngine.availability(locale: selectedLocale)
        cleanupAvailability = cleanupService.availability()
    }

    func requestCorePermissions() {
        Task {
            _ = await PermissionService.requestMicrophone()
            _ = await PermissionService.requestSpeech()
            await refreshSystemState()
        }
    }

    func requestAccessibility() {
        _ = PermissionService.requestAccessibilityPrompt()
        permissions = PermissionService.snapshot()
    }

    func toggleRecording() {
        if status == .listening {
            stopRecording()
        } else {
            startRecording()
        }
    }

    func startRecording() {
        latestError = nil
        liveTranscript = ""
        cleanedText = ""

        guard PermissionService.microphoneState() == .granted else {
            status = .error
            latestError = "Microphone permission is required."
            return
        }

        do {
            activeAudioURL = try recorder.startRecording()
            status = .listening
        } catch {
            status = .error
            latestError = error.localizedDescription
        }
    }

    func stopRecording() {
        guard status == .listening else { return }
        guard let url = recorder.stopRecording() else {
            status = .error
            latestError = "No active recording was found."
            return
        }
        activeAudioURL = url
        Task {
            await processRecording(url)
        }
    }

    func cancelRecording() {
        recorder.discardActiveRecording()
        activeAudioURL = nil
        status = .idle
    }

    func insertLatest() {
        do {
            let didPaste = try insertionService.insertOrCopy(cleanedText, mode: insertionMode)
            status = didPaste ? .inserted : .ready
            if !didPaste {
                latestError = "Copied text. Enable Accessibility permission for automatic paste."
            }
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
                cleanedText = liveTranscript
                latestError = error.localizedDescription
                status = .ready
            }
        }
    }

    private func processRecording(_ url: URL) async {
        do {
            status = .transcribing
            let transcript = try await speechEngine.transcribe(audioFileURL: url, locale: selectedLocale)
            liveTranscript = transcript.text

            status = .cleaning
            let cleaned = try await cleanupService.clean(text: transcript.text, template: selectedTemplate)
            cleanedText = cleaned

            let shouldKeepAudio = audioRetention == .manualDelete
            if !shouldKeepAudio {
                try? FileManager.default.removeItem(at: url)
            }
            let record = DictationRecord(
                targetAppName: TargetAppService.frontmostAppName(),
                rawTranscript: transcript.text,
                cleanedText: cleaned,
                templateID: selectedTemplate.id,
                templateName: selectedTemplate.name,
                languageIdentifier: transcript.languageIdentifier,
                audioFileName: shouldKeepAudio ? url.lastPathComponent : nil
            )
            historyStore.add(record)
            status = .ready
        } catch {
            status = .error
            latestError = error.localizedDescription
        }

        await refreshSystemState()
    }
}

private enum DefaultsKey {
    static let selectedTemplateID = "selectedTemplateID"
    static let insertionMode = "insertionMode"
    static let audioRetention = "audioRetention"
    static let selectedLocaleIdentifier = "selectedLocaleIdentifier"
}
