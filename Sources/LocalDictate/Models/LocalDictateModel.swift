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
    @Published private(set) var menuBarVisualState: MenuBarVisualState = .idle
    @Published private(set) var runtimeDiagnostics: [RuntimeTraceEvent] = []
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
    private var menuBarVisualGeneration = 0
    private var menuBarVisualReturnTask: Task<Void, Never>?

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
        RuntimeDiagnostics.log(scope: "Model", message: "launch called")
        guard !didLaunch else { return }
        didLaunch = true
        historyStore.load()
        templateStore.load()
        registerGlobalHotkey()
        Task {
            await refreshSystemState()
            await refreshRuntimeDiagnostics()
        }
    }

    func refreshSystemState() async {
        RuntimeDiagnostics.log(scope: "Model", message: "refreshSystemState")
        permissions = PermissionService.snapshot()
        refreshAudioInputDevices()
        speechAvailability = await speechEngine.availability(locale: selectedLocale)
        cleanupAvailability = cleanupService.availability()
    }

    func refreshAudioInputDevices() {
        audioInputDevices = AudioInputDeviceService.choices(selectedID: selectedAudioInputDeviceID)
    }

    func requestMicrophonePermission() {
        RuntimeDiagnostics.log(scope: "Permissions", message: "requestMicrophonePermission")
        Task { @MainActor in
            _ = await PermissionService.requestMicrophone()
            permissionNotice = nil
            await refreshSystemState()
        }
    }

    func requestSpeechPermission() {
        RuntimeDiagnostics.log(scope: "Permissions", message: "requestSpeechPermission")
        Task { @MainActor in
            _ = await PermissionService.requestSpeech()
            permissionNotice = nil
            await refreshSystemState()
        }
    }

    @discardableResult
    func requestAccessibility() -> PermissionState {
        RuntimeDiagnostics.log(scope: "Permissions", message: "requestAccessibility")
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
        RuntimeDiagnostics.log(scope: "Recording", message: "toggleRecording", details: "status=\(status)")
        if status == .listening {
            stopRecording()
        } else {
            startRecording()
        }
    }

    func registerGlobalHotkey() {
        RuntimeDiagnostics.log(scope: "Hotkey", message: "registerGlobalHotkey")
        do {
            try hotkeyService.registerCommandD { [weak self] in
                self?.toggleRecording()
            }
            hotkeyDescription = "⌘D"
            hotkeyError = nil
            RuntimeDiagnostics.log(scope: "Hotkey", message: "commandD registered")
        } catch {
            hotkeyError = error.localizedDescription
            RuntimeDiagnostics.log(scope: "Hotkey", message: "registerCommandD failed", details: error.localizedDescription)
        }
    }

    func startRecording() {
        RuntimeDiagnostics.log(scope: "Recording", message: "startRecording", details: "current=\(status)")
        latestError = nil
        didOfferAccessibilityForCurrentRecording = false
        setMenuBarVisual(.idle, reason: "start requested")

        Task { @MainActor in
            let permissionSetup = await ensureRecordingPermissions()
            guard permissionSetup.allGranted else {
                RuntimeDiagnostics.log(scope: "Recording", message: "startRecording blocked: permissions")
                return
            }

            guard await ensureAccessibilityForAutoPasteIfNeeded() else {
                RuntimeDiagnostics.log(scope: "Recording", message: "startRecording blocked: accessibility")
                return
            }

            if permissionSetup.permissionsWereRequested {
                status = .error
                latestError = "Permissions were updated. Press ⌘D again to start recording."
                setMenuBarVisual(.idle, reason: "permissions updated")
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
                setMenuBarVisual(.recording, reason: "recording started")
            } catch {
                RuntimeDiagnostics.log(scope: "Recording", message: "startRecording failed", details: error.localizedDescription)
                status = .error
                latestError = error.localizedDescription
                setMenuBarVisual(.errorFlash, reason: "recording failed")
                await refreshSystemState()
            }
        }
    }

    func stopRecording() {
        RuntimeDiagnostics.log(scope: "Recording", message: "stopRecording", details: "current=\(status)")
        guard status == .listening else { return }
        status = .transcribing
        setMenuBarVisual(.idle, reason: "recording stopped")
        Task { @MainActor in
            do {
                guard let recording = try await recorder.stopRecording() else {
                    RuntimeDiagnostics.log(scope: "Recording", message: "stopRecording found no active recording")
                    status = .error
                    latestError = "No active recording was found."
                    setMenuBarVisual(.errorFlash, reason: "missing recording")
                    return
                }

                activeAudioURL = recording.url
                lastAudioDiagnostics = recording.diagnostics

                if let writeError = recording.diagnostics.writeErrorDescription {
                    latestError = "Audio was transcribed, but saving the optional audio copy failed: \(writeError)"
                    RuntimeDiagnostics.log(scope: "Recording", message: "audio copy save warning", details: writeError)
                }

                guard !recording.diagnostics.isProbablySilent else {
                    RuntimeDiagnostics.log(scope: "Recording", message: "recording appears silent", details: recording.diagnostics.summary)
                    status = .error
                    latestError = "The recording appears silent (\(recording.diagnostics.summary)). Check the Mac input device and microphone level."
                    setMenuBarVisual(.errorFlash, reason: "silent recording")
                    return
                }

                await processRecording(recording)
            } catch {
                RuntimeDiagnostics.log(scope: "Recording", message: "stopRecording failed", details: error.localizedDescription)
                status = .error
                latestError = error.localizedDescription
                setMenuBarVisual(.errorFlash, reason: "stop failed")
                await refreshSystemState()
            }
        }
    }

    func cancelRecording() {
        recorder.discardActiveRecording()
        activeAudioURL = nil
        status = .idle
        setMenuBarVisual(.idle, reason: "recording cancelled")
    }

    func insertLatest() {
        RuntimeDiagnostics.log(scope: "Insertion", message: "insertLatest")
        do {
            applyInsertionOutcome(try insertionService.insertOrCopy(latestText, mode: insertionMode))
        } catch {
            RuntimeDiagnostics.log(scope: "Insertion", message: "insertLatest failed", details: error.localizedDescription)
            latestError = error.localizedDescription
            status = .error
            setMenuBarVisual(.errorFlash, reason: "manual insertion failed")
        }
    }

    func runSampleCleanup() {
        RuntimeDiagnostics.log(scope: "Cleanup", message: "runSampleCleanup")
        liveTranscript = "this is a local dictate test please clean it up and make it useful"
        status = .cleaning
        setMenuBarVisual(.cleaning, reason: "sample cleanup started")
        Task { @MainActor in
            do {
                cleanedText = try await cleanupService.clean(text: liveTranscript, template: selectedTemplate)
                RuntimeDiagnostics.log(scope: "Cleanup", message: "sample cleanup success")
                status = .ready
                setMenuBarVisual(.successFlash, reason: "sample cleanup finished")
            } catch {
                cleanedText = ""
                latestError = "Cleanup failed. Raw transcript is ready: \(error.localizedDescription)"
                RuntimeDiagnostics.log(scope: "Cleanup", message: "sample cleanup failed", details: error.localizedDescription)
                status = .ready
                setMenuBarVisual(.errorFlash, reason: "sample cleanup failed")
            }
        }
    }

    private func processRecording(_ recording: AudioRecordingResult) async {
        RuntimeDiagnostics.log(scope: "Recording", message: "processRecording")
        let transcript = recording.transcript
        liveTranscript = transcript.text

        let shouldKeepAudio = audioRetention == .manualDelete && recording.url != nil
        if !shouldKeepAudio, let url = recording.url {
            try? FileManager.default.removeItem(at: url)
        }

        status = .cleaning
        setMenuBarVisual(.cleaning, reason: "cleanup started")
        var cleanupWarning: String?
        let cleaned: String
        do {
            cleaned = try await cleanupService.clean(text: transcript.text, template: selectedTemplate)
            cleanedText = cleaned
            RuntimeDiagnostics.log(scope: "Cleanup", message: "cleaned transcript", details: "chars=\(transcript.text.count)")
        } catch {
            cleaned = ""
            cleanedText = ""
            cleanupWarning = "Cleanup failed. Raw transcript is ready: \(error.localizedDescription)"
            RuntimeDiagnostics.log(scope: "Cleanup", message: "cleanup failed", details: error.localizedDescription)
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
            RuntimeDiagnostics.log(scope: "Insertion", message: "applying insertion result")
            applyInsertionOutcome(
                try insertionService.insertOrCopy(insertionText, mode: insertionMode),
                fallbackWarning: cleanupWarning
            )
        } catch {
            RuntimeDiagnostics.log(scope: "Insertion", message: "insertion service failed", details: error.localizedDescription)
            status = .error
            latestError = error.localizedDescription
            setMenuBarVisual(.errorFlash, reason: "insertion failed")
        }

        await refreshSystemState()
        await refreshRuntimeDiagnostics()
    }

    private func applyInsertionOutcome(_ outcome: InsertionOutcome, fallbackWarning: String? = nil) {
        RuntimeDiagnostics.log(scope: "Insertion", message: "applyInsertionOutcome", details: "result=\(outcome.result)")
        lastInsertionDiagnostics = outcome.diagnostics

        switch outcome.result {
        case .empty:
            status = .ready
            latestError = fallbackWarning
            setMenuBarVisual(.idle, reason: "empty insertion")
        case .copied:
            latestError = fallbackWarning
            status = .ready
            setMenuBarVisual(.successFlash, reason: "text copied")
        case .pasted:
            latestError = fallbackWarning
            status = .inserted
            setMenuBarVisual(.successFlash, reason: "text pasted")
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
            setMenuBarVisual(.successFlash, reason: "copied after accessibility block")
        case .noEditableTextField:
            latestError = "No editable text field is focused. Text is ready in LocalDictate."
            status = .ready
            setMenuBarVisual(.successFlash, reason: "text ready without focused field")
        }
    }

    private func ensureAccessibilityForAutoPasteIfNeeded() async -> Bool {
        RuntimeDiagnostics.log(scope: "Permissions", message: "ensureAccessibilityForAutoPasteIfNeeded")
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
        setMenuBarVisual(.idle, reason: "accessibility permission required")
        await refreshSystemState()
        RuntimeDiagnostics.log(scope: "Permissions", message: "auto-paste permission not granted")
        return false
    }

    private func ensureRecordingPermissions() async -> (allGranted: Bool, permissionsWereRequested: Bool) {
        RuntimeDiagnostics.log(scope: "Permissions", message: "ensureRecordingPermissions")
        let microphoneResult = await resolveMicrophonePermission()
        let speechResult = await resolveSpeechPermission()
        let permissionsWereRequested = microphoneResult.requested || speechResult.requested

        guard microphoneResult.state == .granted else {
            RuntimeDiagnostics.log(scope: "Permissions", message: "microphone not granted", details: "state=\(microphoneResult.state)")
            status = .error
            latestError = permissionError(
                permissionName: "Microphone",
                state: microphoneResult.state,
                settingsPath: "System Settings > Privacy & Security > Microphone"
            )
            setMenuBarVisual(.idle, reason: "microphone permission required")
            await refreshSystemState()
            return (allGranted: false, permissionsWereRequested: permissionsWereRequested)
        }

        guard speechResult.state == .granted else {
            RuntimeDiagnostics.log(scope: "Permissions", message: "speech not granted", details: "state=\(speechResult.state)")
            status = .error
            latestError = permissionError(
                permissionName: "Speech Recognition",
                state: speechResult.state,
                settingsPath: "System Settings > Privacy & Security > Speech Recognition"
            )
            setMenuBarVisual(.idle, reason: "speech permission required")
            await refreshSystemState()
            return (allGranted: false, permissionsWereRequested: permissionsWereRequested)
        }

        await refreshSystemState()
        return (allGranted: true, permissionsWereRequested: permissionsWereRequested)
    }

    private func resolveMicrophonePermission() async -> (state: PermissionState, requested: Bool) {
        RuntimeDiagnostics.log(scope: "Permissions", message: "resolveMicrophonePermission")
        let state = PermissionService.microphoneState()
        guard state == .notDetermined else {
            return (state, false)
        }

        return (await PermissionService.requestMicrophone(), true)
    }

    private func resolveSpeechPermission() async -> (state: PermissionState, requested: Bool) {
        RuntimeDiagnostics.log(scope: "Permissions", message: "resolveSpeechPermission")
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
        RuntimeDiagnostics.log(scope: "Recognition", message: "appendSpeechDebugEvent", details: event.decision.rawValue)
        speechDebugEvents.insert(event, at: 0)
        if speechDebugEvents.count > 80 {
            speechDebugEvents.removeLast(speechDebugEvents.count - 80)
        }
    }

    func refreshRuntimeDiagnostics() async {
        runtimeDiagnostics = await RuntimeDiagnostics.shared.snapshot(limit: 40)
    }

    func clearRuntimeDiagnostics() {
        runtimeDiagnostics.removeAll()
        Task {
            await RuntimeDiagnostics.shared.clear()
        }
    }

    private func setMenuBarVisual(_ kind: MenuBarVisualKind, reason: String) {
        menuBarVisualGeneration += 1
        let nextState = MenuBarVisualState(kind: kind, generation: menuBarVisualGeneration)
        RuntimeDiagnostics.log(
            scope: "MenuBar",
            message: "visual state changed",
            details: "kind=\(kind.rawValue) generation=\(nextState.generation) reason=\(reason)"
        )
        menuBarVisualState = nextState
        menuBarVisualReturnTask?.cancel()

        guard let delay = kind.returnsToIdleAfterNanoseconds else { return }
        menuBarVisualReturnTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, self.menuBarVisualState == nextState else { return }
                self.setMenuBarVisual(.idle, reason: "\(kind.rawValue) completed")
            }
        }
    }
}

private enum DefaultsKey {
    static let selectedTemplateID = "selectedTemplateID"
    static let audioRetention = "audioRetention"
    static let selectedAudioInputDeviceID = "selectedAudioInputDeviceID"
    static let selectedLocaleIdentifier = "selectedLocaleIdentifier"
}
