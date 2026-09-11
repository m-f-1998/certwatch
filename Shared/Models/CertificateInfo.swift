import Foundation

struct CertificateInfo: Equatable, Sendable, Codable {
    var subjectCommonName: String?
    var subjectAlternativeNames: [String]
    var issuerCommonName: String?
    var validFrom: Date
    var validUntil: Date
    var serialNumber: String
    var signatureAlgorithm: String
    var publicKeyDescription: String
    var pemRepresentation: String
    var chain: [CertificateInfo]

    var leaf: CertificateInfo {
        chain.first ?? self
    }
}

extension CertificateInfo {
    static func preview() -> CertificateInfo {
        let now = Date()
        return CertificateInfo(
            subjectCommonName: "api.example.com",
            subjectAlternativeNames: ["api.example.com", "www.example.com"],
            issuerCommonName: "Let's Encrypt R3",
            validFrom: now.addingTimeInterval(-60 * 86_400),
            validUntil: now.addingTimeInterval(38 * 86_400),
            serialNumber: "04:A1:B2:C3:D4",
            signatureAlgorithm: "SHA-256 with RSA Encryption",
            publicKeyDescription: "RSA (2048 bits)",
            pemRepresentation: "-----BEGIN CERTIFICATE-----\nMIIB...\n-----END CERTIFICATE-----",
            chain: []
        )
    }
}
