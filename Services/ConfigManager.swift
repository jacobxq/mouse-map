import Foundation
import Combine

class ConfigManager: ObservableObject {
    @Published var config: AppConfiguration

    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("MouseMap", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("config.json")

        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(AppConfiguration.self, from: data) {
            config = decoded
        } else {
            config = .default
            save()
        }
    }

    func save() {
        guard let data = try? JSONEncoder().encode(config) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func updateMapping(id: UUID, action: MappingAction) {
        if let idx = config.mappings.firstIndex(where: { $0.id == id }) {
            config.mappings[idx].action = action
            save()
        }
    }

    func addMapping(_ mapping: ButtonMapping) {
        if config.mappings.contains(where: { $0.buttonNumber == mapping.buttonNumber }) { return }
        config.mappings.append(mapping)
        save()
    }

    func removeMapping(id: UUID) {
        config.mappings.removeAll { $0.id == id }
        save()
    }

    func setEnabled(_ enabled: Bool) {
        config.isEnabled = enabled
        save()
    }
}
