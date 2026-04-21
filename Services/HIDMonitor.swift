import IOKit
import IOKit.hid
import ApplicationServices
import Foundation

class HIDMonitor {
    private final class ButtonElementState {
        let usage: Int
        let buttonNumber: Int
        let element: IOHIDElement

        init(usage: Int, element: IOHIDElement) {
            self.usage = usage
            self.buttonNumber = usage - 1
            self.element = element
        }
    }

    private final class DeviceState {
        let registryID: UInt64
        let name: String
        let device: IOHIDDevice
        let buttonElements: [ButtonElementState]
        var buttonStates: [Int: Bool]

        init(
            registryID: UInt64,
            name: String,
            device: IOHIDDevice,
            buttonElements: [ButtonElementState],
            buttonStates: [Int: Bool]
        ) {
            self.registryID = registryID
            self.name = name
            self.device = device
            self.buttonElements = buttonElements
            self.buttonStates = buttonStates
        }
    }

    private var manager: IOHIDManager?
    private let configManager: ConfigManager
    private var lastButtonPressTime: [Int: UInt64] = [:]
    private let debounceIntervalNanos: UInt64 = 200_000_000
    private var deviceStates: [UInt64: DeviceState] = [:]

    var onButtonDetected: ((Int) -> Void)?
    var onHandlingButtonsChanged: ((Bool) -> Void)?
    var isLearning = false
    private(set) var isRunning = false
    private(set) var isHandlingButtons = false

    func log(_ message: String) {
        fputs("[MouseMap HID] \(message)\n", stderr)
    }

    init(configManager: ConfigManager) {
        self.configManager = configManager
    }

    func start() {
        guard !isRunning else {
            log("HID monitor already running")
            return
        }

        guard AXIsProcessTrusted() else {
            log("HID: no permission")
            return
        }

        let mgr = IOHIDManagerCreate(kCFAllocatorDefault, 0)

        let mouseMatching: [String: Any] = [
            kIOHIDDeviceUsagePageKey: 0x01,
            kIOHIDDeviceUsageKey: 0x02
        ]
        IOHIDManagerSetDeviceMatching(mgr, mouseMatching as CFDictionary)
        IOHIDManagerScheduleWithRunLoop(mgr, CFRunLoopGetCurrent(), CFRunLoopMode.commonModes.rawValue)

        let pointer = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(mgr, hidDeviceMatchedCallback, pointer)
        IOHIDManagerRegisterDeviceRemovalCallback(mgr, hidDeviceRemovedCallback, pointer)
        IOHIDManagerRegisterInputReportCallback(mgr, hidInputReportCallback, pointer)

        let result = IOHIDManagerOpen(mgr, 0)
        guard result == kIOReturnSuccess else {
            log("IOHIDManagerOpen failed: \(result)")
            IOHIDManagerUnscheduleFromRunLoop(mgr, CFRunLoopGetCurrent(), CFRunLoopMode.commonModes.rawValue)
            return
        }

        manager = mgr
        isRunning = true
        log("HID manager opened")

        if let devices = IOHIDManagerCopyDevices(mgr) {
            for case let device as IOHIDDevice in (devices as NSSet) {
                registerDevice(device)
            }
        }
    }

    func stop() {
        guard let mgr = manager else { return }

        IOHIDManagerClose(mgr, 0)
        IOHIDManagerUnscheduleFromRunLoop(mgr, CFRunLoopGetCurrent(), CFRunLoopMode.commonModes.rawValue)

        manager = nil
        deviceStates.removeAll()
        isRunning = false
        updateHandlingButtons(false)
        log("HID monitor stopped")
    }

    func handleReport(
        sender: UnsafeMutableRawPointer?,
        type: IOHIDReportType,
        reportID: UInt32,
        report: UnsafeMutablePointer<UInt8>,
        reportLength: CFIndex
    ) {
        guard type == kIOHIDReportTypeInput else { return }
        guard let sender else { return }

        let device = unsafeBitCast(sender, to: IOHIDDevice.self)
        guard let registryID = registryID(for: device) else { return }

        if deviceStates[registryID] == nil {
            registerDevice(device)
        }

        guard let deviceState = deviceStates[registryID] else { return }

        let timestamp = DispatchTime.now().uptimeNanoseconds

        for button in deviceState.buttonElements {
            let isPressed = currentButtonState(for: button.element, on: device)
            let wasPressed = deviceState.buttonStates[button.buttonNumber] ?? false
            deviceState.buttonStates[button.buttonNumber] = isPressed

            if isPressed && !wasPressed {
                log("Button \(button.buttonNumber) pressed via report id=\(reportID) len=\(reportLength)")
                handleButtonPress(buttonNumber: button.buttonNumber, timestamp: timestamp)
            }
        }

        _ = report
    }

    func registerDevice(_ device: IOHIDDevice) {
        guard isTargetDevice(device) else { return }
        guard let registryID = registryID(for: device) else { return }
        guard deviceStates[registryID] == nil else { return }

        let buttonElements = loadButtonElements(for: device)
        guard !buttonElements.isEmpty else { return }

        let name = stringProperty("Product", on: device) ?? "unknown"
        let buttonStates = Dictionary(uniqueKeysWithValues: buttonElements.map { button in
            (button.buttonNumber, currentButtonState(for: button.element, on: device))
        })

        deviceStates[registryID] = DeviceState(
            registryID: registryID,
            name: name,
            device: device,
            buttonElements: buttonElements,
            buttonStates: buttonStates
        )
        updateHandlingButtons(true)

        let buttons = buttonElements.map(\.buttonNumber).sorted().map(String.init).joined(separator: ", ")
        log("Device matched: \(name), buttons=[\(buttons)]")
    }

    func unregisterDevice(_ device: IOHIDDevice) {
        guard let registryID = registryID(for: device) else { return }
        guard let removed = deviceStates.removeValue(forKey: registryID) else { return }

        log("Device removed: \(removed.name)")
        updateHandlingButtons(!deviceStates.isEmpty)
    }

    private func handleButtonPress(buttonNumber: Int, timestamp: UInt64) {
        if let lastTime = lastButtonPressTime[buttonNumber], (timestamp - lastTime) < debounceIntervalNanos {
            return
        }
        lastButtonPressTime[buttonNumber] = timestamp

        if isLearning {
            onButtonDetected?(buttonNumber)
            isLearning = false
            return
        }

        guard configManager.config.isEnabled else { return }

        let action = configManager.config.action(for: buttonNumber)
        if action != .disabled {
            KeyEventSimulator.simulate(action: action)
        }
    }

    private func updateHandlingButtons(_ newValue: Bool) {
        guard isHandlingButtons != newValue else { return }
        isHandlingButtons = newValue
        onHandlingButtonsChanged?(newValue)
        log("HID button handling \(newValue ? "enabled" : "disabled")")
    }

    private func isTargetDevice(_ device: IOHIDDevice) -> Bool {
        let vendorID = intProperty("VendorID", on: device)
        let productID = intProperty("ProductID", on: device)
        let name = stringProperty("Product", on: device) ?? ""

        return vendorID == 0x046D && (productID == 0xC08B || name.contains("G502"))
    }

    private func loadButtonElements(for device: IOHIDDevice) -> [ButtonElementState] {
        guard let elements = IOHIDDeviceCopyMatchingElements(device, nil, 0) else {
            return []
        }

        var buttons: [ButtonElementState] = []

        for case let element as IOHIDElement in (elements as NSArray) {
            let usagePage = Int(IOHIDElementGetUsagePage(element))
            let usage = Int(IOHIDElementGetUsage(element))

            guard usagePage == 0x09 else { continue }
            guard usage >= 3 else { continue }

            buttons.append(ButtonElementState(usage: usage, element: element))
        }

        return buttons.sorted { lhs, rhs in
            lhs.usage < rhs.usage
        }
    }

    private func currentButtonState(for element: IOHIDElement, on device: IOHIDDevice) -> Bool {
        var value: Unmanaged<IOHIDValue>?
        let result = withUnsafeMutablePointer(to: &value) { pointer in
            pointer.withMemoryRebound(to: Unmanaged<IOHIDValue>.self, capacity: 1) { rebound in
                IOHIDDeviceGetValue(device, element, rebound)
            }
        }
        guard result == kIOReturnSuccess, let value else {
            return false
        }

        return IOHIDValueGetIntegerValue(value.takeUnretainedValue()) != 0
    }

    private func registryID(for device: IOHIDDevice) -> UInt64? {
        let service = IOHIDDeviceGetService(device)
        guard service != MACH_PORT_NULL else { return nil }

        var registryID: UInt64 = 0
        let result = IORegistryEntryGetRegistryEntryID(service, &registryID)
        guard result == KERN_SUCCESS else { return nil }

        return registryID
    }

    private func stringProperty(_ key: String, on device: IOHIDDevice) -> String? {
        IOHIDDeviceGetProperty(device, key as CFString) as? String
    }

    private func intProperty(_ key: String, on device: IOHIDDevice) -> Int? {
        if let number = IOHIDDeviceGetProperty(device, key as CFString) as? NSNumber {
            return number.intValue
        }
        return nil
    }
}

private func hidInputReportCallback(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    type: IOHIDReportType,
    reportID: UInt32,
    report: UnsafeMutablePointer<UInt8>,
    reportLength: CFIndex
) {
    guard let context, result == kIOReturnSuccess else { return }
    let monitor = Unmanaged<HIDMonitor>.fromOpaque(context).takeUnretainedValue()
    monitor.handleReport(
        sender: sender,
        type: type,
        reportID: reportID,
        report: report,
        reportLength: reportLength
    )
}

private func hidDeviceMatchedCallback(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    device: IOHIDDevice
) {
    guard let context, result == kIOReturnSuccess else { return }
    let monitor = Unmanaged<HIDMonitor>.fromOpaque(context).takeUnretainedValue()
    monitor.registerDevice(device)
    _ = sender
}

private func hidDeviceRemovedCallback(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    device: IOHIDDevice
) {
    guard let context, result == kIOReturnSuccess else { return }
    let monitor = Unmanaged<HIDMonitor>.fromOpaque(context).takeUnretainedValue()
    monitor.unregisterDevice(device)
    _ = sender
}
