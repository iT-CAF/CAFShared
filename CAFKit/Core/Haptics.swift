import UIKit
import AudioToolbox

/// Haptics + short system sounds for scan outcomes (success / warning / error feel different).
@MainActor
enum Haptics {
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
    static func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success); AudioServicesPlaySystemSound(1057) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning); AudioServicesPlaySystemSound(1053) }
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error); AudioServicesPlaySystemSound(1073) }
}
