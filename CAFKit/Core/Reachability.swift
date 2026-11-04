import Foundation
import Network

/// Wi-Fi/cellular availability (a hint only — real failures are detected by the requests themselves).
@Observable
@MainActor
final class Reachability {
    private(set) var isOnline = true
    private let monitor = NWPathMonitor()
    var onChange: ((Bool) -> Void)?

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let on = path.status == .satisfied
            Task { @MainActor in
                guard let self else { return }
                let changed = self.isOnline != on
                self.isOnline = on
                if changed { self.onChange?(on) }
            }
        }
        monitor.start(queue: DispatchQueue(label: "reachability"))
    }
    deinit { monitor.cancel() }
}
