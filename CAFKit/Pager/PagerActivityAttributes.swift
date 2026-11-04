import Foundation
import ActivityKit

/// The smart-pager Live Activity (lock screen + Dynamic Island), shared by the App Clip UI and its widget extension.
/// The server pushes `ContentState` as-is (`cafbio-clips/src/Devices.php` contentState()), so the property names below are
/// the wire keys: do not rename them and do not add a key-decoding strategy.
struct PagerActivityAttributes: ActivityAttributes {
    /// Stage numbers of the server: 2 preparing, 6 ready, 3 picked up, 4 cancelled.
    enum Stage {
        static let preparing = 2, ready = 6, picked = 3, cancelled = 4
    }

    struct ContentState: Codable, Hashable, Sendable {
        var stage: Int
        var title: String
        var subtitle: String
        /// Unix seconds when the order is expected to be ready; nil when unknown.
        var eta: Int?
        var progress: Double
        var order_number: String
        var product_title: String

        var isFinished: Bool { stage == Stage.picked || stage == Stage.cancelled }
        var isReady: Bool { stage == Stage.ready }
        var etaDate: Date? { eta.map { Date(timeIntervalSince1970: TimeInterval($0)) } }
    }

    // Static for the whole activity: set once when it starts.
    var businessName: String
    var logoURL: String
    var colorHex: String
    var branchName: String
    var ticketToken: String
}
