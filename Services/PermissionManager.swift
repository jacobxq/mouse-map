import ApplicationServices
import Combine

class PermissionManager: ObservableObject {
    @Published var isGranted = false

    private var timer: Timer?

    init() {
        isGranted = AXIsProcessTrusted()
        startPolling()
    }

    deinit {
        timer?.invalidate()
    }

    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    private func startPolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.isGranted = AXIsProcessTrusted()
            }
        }
    }
}
