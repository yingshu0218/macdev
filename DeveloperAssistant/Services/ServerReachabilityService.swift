import Foundation
import Network

enum ServerReachabilityResult: Sendable, Equatable {
    case reachable(latencyMilliseconds: Int)
    case unreachable
}

struct ServerReachabilityService: Sendable {
    func check(host: String, port: Int, timeout: TimeInterval = 5) async -> ServerReachabilityResult {
        guard let networkPort = NWEndpoint.Port(rawValue: UInt16(port)) else { return .unreachable }

        return await withCheckedContinuation { continuation in
            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: networkPort,
                using: .tcp
            )
            let probe = ConnectionProbe(
                connection: connection,
                startedAt: ContinuousClock.now,
                continuation: continuation
            )
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    probe.finish(.reachable(latencyMilliseconds: probe.elapsedMilliseconds))
                case .failed, .cancelled:
                    probe.finish(.unreachable)
                default:
                    break
                }
            }
            connection.start(queue: DispatchQueue(label: "com.infinity.developer-assistant.server-probe"))
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
                probe.finish(.unreachable)
            }
        }
    }
}

private final class ConnectionProbe: @unchecked Sendable {
    private let lock = NSLock()
    private let connection: NWConnection
    private let startedAt: ContinuousClock.Instant
    private let continuation: CheckedContinuation<ServerReachabilityResult, Never>
    private var didFinish = false

    init(
        connection: NWConnection,
        startedAt: ContinuousClock.Instant,
        continuation: CheckedContinuation<ServerReachabilityResult, Never>
    ) {
        self.connection = connection
        self.startedAt = startedAt
        self.continuation = continuation
    }

    var elapsedMilliseconds: Int {
        let duration = startedAt.duration(to: ContinuousClock.now)
        return max(1, Int(duration.components.seconds * 1_000)
            + Int(duration.components.attoseconds / 1_000_000_000_000_000))
    }

    func finish(_ result: ServerReachabilityResult) {
        lock.lock()
        guard !didFinish else {
            lock.unlock()
            return
        }
        didFinish = true
        lock.unlock()

        connection.stateUpdateHandler = nil
        connection.cancel()
        continuation.resume(returning: result)
    }
}
