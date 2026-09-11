import Foundation
import Security

enum CertificatePEMParser {
    static func parseMultiple(from pem: String) -> [CertificateInfo] {
        let blocks = pem
            .components(separatedBy: "-----END CERTIFICATE-----")
            .compactMap { chunk -> String? in
                guard chunk.contains("-----BEGIN CERTIFICATE-----") else { return nil }
                return chunk.trimmingCharacters(in: .whitespacesAndNewlines) + "\n-----END CERTIFICATE-----"
            }

        return blocks.compactMap { parseSingle(from: $0) }
    }

    static func parseSingle(from pem: String) -> CertificateInfo? {
        guard let data = decodePEM(pem) else { return nil }
        guard let certificate = SecCertificateCreateWithData(nil, data as CFData) else { return nil }
        return CertificateParser.parse(certificate)
    }

    static func decodePEM(_ pem: String) -> Data? {
        let lines = pem
            .replacingOccurrences(of: "-----BEGIN CERTIFICATE-----", with: "")
            .replacingOccurrences(of: "-----END CERTIFICATE-----", with: "")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        return Data(base64Encoded: lines.joined())
    }
}
