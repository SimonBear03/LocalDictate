import AVFoundation
import LocalDictateCore

@MainActor
final class AudioRecorderService: NSObject, AVAudioRecorderDelegate {
    private var recorder: AVAudioRecorder?
    private(set) var activeRecordingURL: URL?

    var isRecording: Bool {
        recorder?.isRecording == true
    }

    func startRecording() throws -> URL {
        let directory = try AppPaths.recordingsDirectory()
        let fileName = "dictation-\(Self.timestampFormatter.string(from: Date())).wav"
        let url = directory.appendingPathComponent(fileName)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.delegate = self
        recorder.isMeteringEnabled = true
        recorder.prepareToRecord()
        recorder.record()
        self.recorder = recorder
        activeRecordingURL = url
        return url
    }

    func stopRecording() -> URL? {
        guard let recorder else {
            return activeRecordingURL
        }
        recorder.stop()
        self.recorder = nil
        return activeRecordingURL
    }

    func discardActiveRecording() {
        if let recorder, recorder.isRecording {
            recorder.stop()
        }
        if let activeRecordingURL {
            try? FileManager.default.removeItem(at: activeRecordingURL)
        }
        recorder = nil
        activeRecordingURL = nil
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
}
