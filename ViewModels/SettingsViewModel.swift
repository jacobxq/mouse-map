import SwiftUI
import Combine

class SettingsViewModel: ObservableObject {
    @Published var config: AppConfiguration
    @Published var isLearning = false

    private let configManager: ConfigManager
    private let eventTapManager: EventTapManager
    private let hidMonitor: HIDMonitor

    init(configManager: ConfigManager, eventTapManager: EventTapManager, hidMonitor: HIDMonitor) {
        self.configManager = configManager
        self.eventTapManager = eventTapManager
        self.hidMonitor = hidMonitor
        self.config = configManager.config

        configManager.$config
            .receive(on: DispatchQueue.main)
            .assign(to: &$config)

        let onDetected: (Int) -> Void = { [weak self] buttonNumber in
            guard let self else { return }
            let name = "按键 \(buttonNumber + 1)"
            let mapping = ButtonMapping(buttonNumber: buttonNumber, action: .desktopLeft, displayName: name)
            self.configManager.addMapping(mapping)
            self.isLearning = false
        }

        hidMonitor.onButtonDetected = onDetected
        eventTapManager.onButtonDetected = onDetected
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
        hidMonitor.isLearning = true
    }

    func cancelLearning() {
        isLearning = false
        eventTapManager.isLearning = false
        hidMonitor.isLearning = false
    }
}
