import SwiftUI
import Combine

class SettingsViewModel: ObservableObject {
    @Published var config: AppConfiguration
    @Published var isLearning = false

    private let configManager: ConfigManager
    private let eventTapManager: EventTapManager

    init(configManager: ConfigManager, eventTapManager: EventTapManager) {
        self.configManager = configManager
        self.eventTapManager = eventTapManager
        self.config = configManager.config

        configManager.$config
            .receive(on: DispatchQueue.main)
            .assign(to: &$config)

        eventTapManager.onButtonDetected = { [weak self] buttonNumber in
            guard let self else { return }
            let name = "按键 \(buttonNumber + 1)"
            let mapping = ButtonMapping(buttonNumber: buttonNumber, action: .desktopLeft, displayName: name)
            self.configManager.addMapping(mapping)
            self.isLearning = false
        }
    }

    func updateAction(id: UUID, action: MappingAction) {
        configManager.updateMapping(id: id, action: action)
    }

    func removeMapping(id: UUID) {
        configManager.removeMapping(id: id)
    }

    func setEnabled(_ enabled: Bool) {
        configManager.setEnabled(enabled)
    }

    func startLearning() {
        isLearning = true
        eventTapManager.isLearning = true
    }

    func cancelLearning() {
        isLearning = false
        eventTapManager.isLearning = false
    }
}
