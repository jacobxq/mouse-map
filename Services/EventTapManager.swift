import CoreGraphics
import ApplicationServices
import Foundation

class EventTapManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let configManager: ConfigManager
    private var suppressedButton: Int?
    var onButtonDetected: ((Int) -> Void)?
    var isLearning = false
    var hidMonitorActive = false

    private func log(_ message: String) {
        fputs("[MouseMap] \(message)\n", stderr)
    }

    init(configManager: ConfigManager) {
        self.configManager = configManager
    }

    func start() {
        guard eventTap == nil else {
            log("Event tap already active, skipping")
            return
        }

        guard AXIsProcessTrusted() else {
            log("ERROR: Accessibility permission not granted, cannot create event tap")
            return
        }

        var eventMask: CGEventMask = 0
        eventMask |= (1 << CGEventType.leftMouseDown.rawValue)
        eventMask |= (1 << CGEventType.leftMouseUp.rawValue)
        eventMask |= (1 << CGEventType.rightMouseDown.rawValue)
        eventMask |= (1 << CGEventType.rightMouseUp.rawValue)
        eventMask |= (1 << CGEventType.otherMouseDown.rawValue)
        eventMask |= (1 << CGEventType.otherMouseUp.rawValue)

        let pointer = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: eventCallback,
            userInfo: pointer
        ) else {
            log("ERROR: CGEvent.tapCreate returned nil — tap creation failed")
            return
        }

        self.eventTap = tap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        log("Event tap created and enabled successfully")
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        suppressedButton = nil
    }

    func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout {
            log("Tap disabled by timeout, re-enabling")
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return nil
        }

        if type == .tapDisabledByUserInput {
            log("Tap disabled by user input (permission revoked)")
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: false)
            }
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            }
            eventTap = nil
            runLoopSource = nil
            suppressedButton = nil
            return nil
        }

        let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)

        if isLearning {
            log("Learning: event type=\(type.rawValue) button=\(buttonNumber)")
        }

        if type == .otherMouseUp || type == .leftMouseUp || type == .rightMouseUp {
            if let suppressed = suppressedButton, suppressed == buttonNumber {
                suppressedButton = nil
                return nil
            }
            return Unmanaged.passUnretained(event)
        }

        if isLearning {
            if type == .otherMouseDown && !hidMonitorActive {
                log("Learning: captured other button \(buttonNumber)")
                DispatchQueue.main.async { [weak self] in
                    self?.onButtonDetected?(Int(buttonNumber))
                    self?.isLearning = false
                }
                suppressedButton = Int(buttonNumber)
                return nil
            }
            return Unmanaged.passUnretained(event)
        }

        guard configManager.config.isEnabled else {
            return Unmanaged.passUnretained(event)
        }

        guard type == .otherMouseDown else {
            return Unmanaged.passUnretained(event)
        }

        let action = configManager.config.action(for: Int(buttonNumber))

        if action != .disabled {
            suppressedButton = Int(buttonNumber)
            if !hidMonitorActive {
                KeyEventSimulator.simulate(action: action)
            }
            return nil
        }

        return Unmanaged.passUnretained(event)
    }
}

private func eventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo = userInfo else { return Unmanaged.passUnretained(event) }
    let manager = Unmanaged<EventTapManager>.fromOpaque(userInfo).takeUnretainedValue()
    return manager.handleEvent(type: type, event: event)
}
