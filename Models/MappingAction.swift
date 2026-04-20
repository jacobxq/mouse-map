import Foundation
import CoreGraphics

enum MappingAction: String, Codable, CaseIterable, Identifiable {
    case disabled
    case desktopLeft
    case desktopRight
    case missionControl
    case appExpose
    case showDesktop

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .disabled:       return "禁用"
        case .desktopLeft:    return "切换到左侧桌面"
        case .desktopRight:   return "切换到右侧桌面"
        case .missionControl: return "调度中心"
        case .appExpose:      return "应用程序窗口"
        case .showDesktop:    return "显示桌面"
        }
    }

    var keyCode: CGKeyCode? {
        switch self {
        case .desktopLeft:    return 123  // Left Arrow
        case .desktopRight:   return 124  // Right Arrow
        case .missionControl: return 126  // Up Arrow
        case .appExpose:      return 125  // Down Arrow
        case .showDesktop:    return 11   // F11
        default: return nil
        }
    }

    var modifierFlags: CGEventFlags? {
        switch self {
        case .desktopLeft, .desktopRight, .missionControl, .appExpose:
            return .maskAlternate
        case .showDesktop:
            return []
        default: return nil
        }
    }
}
