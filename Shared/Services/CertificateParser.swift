import Foundation
import Security

enum CertificateParser {
    static func parse(_ certificate: SecCertificate) -> CertificateInfo {
        let data = SecCertificateCopyData(certificate) as Data
        let summary = SecCertificateCopySubjectSummary(certificate) as String?
        let derFields = X509DERParser.parseFields(from: data)

        let validFrom = copyNotValidBefore(from: certificate) ?? derFields.validFrom ?? .distantPast
        let validUntil = copyNotValidAfter(from: certificate) ?? derFields.validUntil ?? .distantFuture
        let subject = copyCommonName(from: certificate) ?? summary
        let issuer = derFields.issuerCommonName
            ?? X509DERParser.commonName(fromDN: copyNormalizedIssuerSequence(from: certificate) ?? Data())
            ?? "Unknown Issuer"
        let sans = derFields.subjectAlternativeNames
        let serial = copySerialNumber(from: certificate) ?? "Unknown"
        let signature = derFields.signatureAlgorithm ?? "Unknown"
        let publicKey = publicKeyDescription(from: certificate)

        let pem = """
        -----BEGIN CERTIFICATE-----
        \(data.base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed]))
        -----END CERTIFICATE-----
        """

        return CertificateInfo(
            subjectCommonName: subject,
            subjectAlternativeNames: sans,
            issuerCommonName: issuer,
            validFrom: validFrom,
            validUntil: validUntil,
            serialNumber: serial,
            signatureAlgorithm: signature,
            publicKeyDescription: publicKey,
            pemRepresentation: pem,
            chain: []
        )
    }

    static func parseChain(from trust: SecTrust) -> CertificateInfo? {
        let certificates = copyCertificateChain(from: trust)
        guard !certificates.isEmpty else { return nil }

        let nodes = certificates.map { parse($0) }
        guard let leaf = nodes.first else { return nil }

        var chainRoot = leaf
        chainRoot.chain = Array(nodes.dropFirst())
        return chainRoot
    }

    private static func copyCertificateChain(from trust: SecTrust) -> [SecCertificate] {
        guard let cfChain = SecTrustCopyCertificateChain(trust) else { return [] }
        let count = CFArrayGetCount(cfChain)
        guard count > 0 else { return [] }

        return (0..<count).compactMap { index in
            guard let value = CFArrayGetValueAtIndex(cfChain, index) else { return nil }
            return Unmanaged<SecCertificate>.fromOpaque(value).takeUnretainedValue()
        }
    }

    private static func copyNotValidBefore(from certificate: SecCertificate) -> Date? {
        if #available(iOS 18.0, *) {
            return SecCertificateCopyNotValidBeforeDate(certificate) as Date?
        }
        return nil
    }

    private static func copyNotValidAfter(from certificate: SecCertificate) -> Date? {
        if #available(iOS 18.0, *) {
            return SecCertificateCopyNotValidAfterDate(certificate) as Date?
        }
        return nil
    }

    private static func copyCommonName(from certificate: SecCertificate) -> String? {
        var commonName: CFString?
        let status = SecCertificateCopyCommonName(certificate, &commonName)
        guard status == errSecSuccess, let commonName else { return nil }
        return commonName as String
    }

    private static func copyNormalizedIssuerSequence(from certificate: SecCertificate) -> Data? {
        SecCertificateCopyNormalizedIssuerSequence(certificate) as Data?
    }

    private static func copySerialNumber(from certificate: SecCertificate) -> String? {
        var error: Unmanaged<CFError>?
        guard let serialData = SecCertificateCopySerialNumberData(certificate, &error) as Data? else {
            return nil
        }
        return serialData.map { String(format: "%02X", $0) }.joined(separator: ":")
    }

    private static func publicKeyDescription(from certificate: SecCertificate) -> String {
        guard let key = SecCertificateCopyKey(certificate),
              let attributes = SecKeyCopyAttributes(key) as? [String: Any] else {
            return "Unknown"
        }

        let keyType = attributes[kSecAttrKeyType as String]
        let keySize = attributes[kSecAttrKeySizeInBits as String] as? Int

        if matchesKeyType(keyType, kSecAttrKeyTypeRSA) {
            if let keySize {
                return "RSA (\(keySize) bits)"
            }
            return "RSA key"
        }

        if matchesKeyType(keyType, kSecAttrKeyTypeECSECPrimeRandom) {
            if let keySize {
                return "EC (\(keySize) bits)"
            }
            return "EC key"
        }

        if let keySize {
            return "Key (\(keySize) bits)"
        }
        return "Unknown"
    }

    private static func matchesKeyType(_ value: Any?, _ expected: CFString) -> Bool {
        guard let value else { return false }
        if let string = value as? String {
            return string == (expected as String)
        }
        return CFEqual(value as CFTypeRef, expected)
    }
}
