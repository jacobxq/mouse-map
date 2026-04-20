import Foundation
import CoreGraphics

struct ButtonMapping: Codable, Identifiable {
    let id: UUID
    var buttonNumber: Int
    var action: MappingAction
    var displayName: String

    init(id: UUID = UUID(), buttonNumber: Int, action: MappingAction = .disabled, displayName: String? = nil) {
        self.id = id
        self.buttonNumber = buttonNumber
        self.action = action
        self.displayName = displayName ?? "按键 \(buttonNumber + 1)"
    }
}

struct AppConfiguration: Codable {
    var isEnabled: Bool = true
    var mappings: [ButtonMapping] = []

    static let `default` = AppConfiguration(
        isEnabled: true,
        mappings: [
            ButtonMapping(buttonNumber: 3, action: .desktopLeft, displayName: "侧键 1 (后退)"),
            ButtonMapping(buttonNumber: 4, action: .desktopRight, displayName: "侧键 2 (前进)")
        ]
    )

    func action(for buttonNumber: Int) -> MappingAction {
        mappings.first { $0.buttonNumber == buttonNumber }?.action ?? .disabled
    }
}
