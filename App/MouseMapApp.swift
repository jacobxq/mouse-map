import SwiftUI

@main
struct MouseMapApp: App {
    @StateObject private var configManager = ConfigManager()
    @StateObject private var permissionManager = PermissionManager()
    @StateObject private var eventTapManagerWrapper: EventTapManagerWrapper
    @StateObject private var viewModelWrapper: ViewModelWrapper

    @State private var isEnabled = true

    init() {
        let trusted = AXIsProcessTrusted()
        let msg = "[MouseMap] App init started, AXIsProcessTrusted=\(trusted), path=\(Bundle.main.bundlePath)"
        fputs(msg + "\n", stderr)
        try? msg.write(toFile: "/tmp/mousemap_debug.log", atomically: true, encoding: .utf8)
        let cm = ConfigManager()
        let pm = PermissionManager()
        let etm = EventTapManager(configManager: cm)

        _configManager = StateObject(wrappedValue: cm)
        _permissionManager = StateObject(wrappedValue: pm)
        _eventTapManagerWrapper = StateObject(wrappedValue: EventTapManagerWrapper(eventTapManager: etm))
        _viewModelWrapper = StateObject(wrappedValue: ViewModelWrapper(vm: SettingsViewModel(configManager: cm, eventTapManager: etm)))
        _isEnabled = State(wrappedValue: cm.config.isEnabled)
    }

    var body: some Scene {
        MenuBarExtra("MouseMap", systemImage: "cursorarrow.and.square.on.square.dashed") {
            Button("配置...") {
                SettingsWindowManager.shared.show(
                    viewModel: viewModelWrapper.vm,
                    permissionManager: permissionManager
                )
            }

            Divider()

            Toggle("启用", isOn: $isEnabled)
                .onChange(of: isEnabled) { _, newValue in
                    configManager.setEnabled(newValue)
                }

            Divider()

            Button("退出 MouseMap") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

class SettingsWindowManager {
    static let shared = SettingsWindowManager()
    private var window: NSWindow?

    func show(viewModel: SettingsViewModel, permissionManager: PermissionManager) {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingView = NSHostingView(rootView: SettingsView(
            viewModel: viewModel,
            permissionManager: permissionManager
        ))

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "MouseMap 配置"
        newWindow.contentView = hostingView
        newWindow.center()
        newWindow.isReleasedWhenClosed = false
        newWindow.delegate = WindowDelegate.shared
        newWindow.makeKeyAndOrderFront(nil)

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        window = newWindow
    }
}

class WindowDelegate: NSObject, NSWindowDelegate {
    static let shared = WindowDelegate()
    func windowWillClose(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

class EventTapManagerWrapper: ObservableObject {
    let eventTapManager: EventTapManager
    private var timer: Timer?

    init(eventTapManager: EventTapManager) {
        self.eventTapManager = eventTapManager
        startPolling()
    }

    private func startPolling() {
        if AXIsProcessTrusted() {
            eventTapManager.start()
            return
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
            if AXIsProcessTrusted() {
                self?.eventTapManager.start()
                t.invalidate()
                self?.timer = nil
            }
        }
    }
}

class ViewModelWrapper: ObservableObject {
    let vm: SettingsViewModel
    init(vm: SettingsViewModel) {
        self.vm = vm
    }
}
