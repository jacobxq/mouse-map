import ApplicationServices
import Combine

class PermissionManager: ObservableObject {
    @Published var isGranted = false

    private var timer: Timer?

    init() {
        checkAndStartPolling()
    }

    deinit {
        timer?.invalidate()
    }

    func checkAndStartPolling() {
        isGranted = AXIsProcessTrusted()
        if !isGranted {
            startPolling()
        }
    }

    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        startPolling()
    }

    private func startPolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                let granted = AXIsProcessTrusted()
                self?.isGranted = granted
                if granted {
                    self?.timer?.invalidate()
                    self?.timer = nil
                }
            }
        }
    }
}
