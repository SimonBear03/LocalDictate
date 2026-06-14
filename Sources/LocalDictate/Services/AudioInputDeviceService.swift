import AVFoundation

struct AudioInputDeviceChoice: Identifiable, Hashable, Sendable {
    static let systemDefaultID = "system-default"

    var id: String
    var name: String
    var isSystemDefault: Bool

    static let systemDefault = AudioInputDeviceChoice(
        id: systemDefaultID,
        name: "System Default",
        isSystemDefault: true
    )
}

enum AudioInputDeviceService {
    static func choices(selectedID: String) -> [AudioInputDeviceChoice] {
        var choices = [AudioInputDeviceChoice.systemDefault]
        let devices = discoverySession.devices
            .sorted { $0.localizedName.localizedStandardCompare($1.localizedName) == .orderedAscending }
            .map {
                AudioInputDeviceChoice(id: $0.uniqueID, name: $0.localizedName, isSystemDefault: false)
            }

        choices.append(contentsOf: devices)

        if selectedID != AudioInputDeviceChoice.systemDefaultID,
           !choices.contains(where: { $0.id == selectedID }) {
            choices.insert(
                AudioInputDeviceChoice(id: selectedID, name: "Missing Device", isSystemDefault: false),
                at: 1
            )
        }

        var seen = Set<String>()
        return choices.filter { seen.insert($0.id).inserted }
    }

    static func displayName(for id: String) -> String {
        choices(selectedID: id).first { $0.id == id }?.name ?? AudioInputDeviceChoice.systemDefault.name
    }

    static func device(for id: String) -> AVCaptureDevice? {
        guard id != AudioInputDeviceChoice.systemDefaultID else {
            return AVCaptureDevice.default(for: .audio)
        }

        return discoverySession.devices.first { $0.uniqueID == id }
    }

    private static var discoverySession: AVCaptureDevice.DiscoverySession {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .microphone,
                .external
            ],
            mediaType: .audio,
            position: .unspecified
        )
    }
}
