import Foundation
import Network
import Security

protocol CertificateFetching: Sendable {
    func fetchCertificateChain(host: String, port: Int) async throws -> CertificateInfo
}

actor CertificateService: CertificateFetching {
    enum CertError: Error, Equatable, LocalizedError {
        case connectionFailed(String)
        case noCertificatePresented
        case invalidHost
        case timeout

        var errorDescription: String? {
            switch self {
            case .connectionFailed(let message):
                return "Connection failed: \(message)"
            case .noCertificatePresented:
                return "No server certificate presented during TLS handshake."
            case .invalidHost:
                return "Invalid hostname or IP address."
            case .timeout:
                return "Connection timed out after 10 seconds."
            }
        }
    }

    private let totalTimeout: TimeInterval

    init(totalTimeout: TimeInterval = 15) {
        self.totalTimeout = totalTimeout
    }

    func fetchCertificateChain(host: String, port: Int = 443) async throws -> CertificateInfo {
        guard HostnameParser.isValidHostname(host), HostnameParser.isValidPort(port) else {
            throw CertError.invalidHost
        }

        guard let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
            throw CertError.invalidHost
        }

        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: nwPort
        )

        let tlsOptions = NWProtocolTLS.Options()
        sec_protocol_options_set_tls_server_name(tlsOptions.securityProtocolOptions, host)

        final class TrustBox: @unchecked Sendable {
            var trust: SecTrust?
        }
        let trustBox = TrustBox()

        sec_protocol_options_set_verify_block(
            tlsOptions.securityProtocolOptions,
            { _, trust, completion in
                trustBox.trust = sec_trust_copy_ref(trust).takeRetainedValue()
                completion(true)
            },
            DispatchQueue.global(qos: .userInitiated)
        )

        let parameters = NWParameters(tls: tlsOptions)
        let connection = NWConnection(to: endpoint, using: parameters)

        return try await withCheckedThrowingContinuation { continuation in
            final class ResumeState: @unchecked Sendable {
                var resumed = false

                func resumeOnce(_ action: @Sendable () -> Void) {
                    guard !resumed else { return }
                    resumed = true
                    action()
                }
            }
            let resumeState = ResumeState()

            let timeoutTask = Task {
                try await Task.sleep(nanoseconds: UInt64(totalTimeout * 1_000_000_000))
                connection.cancel()
                resumeState.resumeOnce {
                    continuation.resume(throwing: CertError.timeout)
                }
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    timeoutTask.cancel()
                    connection.cancel()
                    guard let trust = trustBox.trust,
                          let chain = CertificateParser.parseChain(from: trust) else {
                        resumeState.resumeOnce {
                            continuation.resume(throwing: CertError.noCertificatePresented)
                        }
                        return
                    }
                    resumeState.resumeOnce {
                        continuation.resume(returning: chain)
                    }

                case .failed(let error):
                    timeoutTask.cancel()
                    connection.cancel()
                    resumeState.resumeOnce {
                        continuation.resume(throwing: CertError.connectionFailed(error.localizedDescription))
                    }

                case .waiting(let error):
                    if case .posix(let code) = error, code == .ETIMEDOUT {
                        timeoutTask.cancel()
                        connection.cancel()
                        resumeState.resumeOnce {
                            continuation.resume(throwing: CertError.timeout)
                        }
                    }

                default:
                    break
                }
            }

            connection.start(queue: .global(qos: .userInitiated))
        }
    }
}

struct MockCertificateService: CertificateFetching {
    var handler: @Sendable (String, Int) async throws -> CertificateInfo

    init(handler: @escaping @Sendable (String, Int) async throws -> CertificateInfo) {
        self.handler = handler
    }

    func fetchCertificateChain(host: String, port: Int) async throws -> CertificateInfo {
        try await handler(host, port)
    }
}
