import Foundation
import SwiftData

@Model
final class MonitoredEndpoint {
    @Attribute(.unique) var id: UUID
    var hostname: String
    var port: Int
    var displayName: String?
    var tag: String?
    var notes: String?
    var createdAt: Date
    var lastCheckedAt: Date?
    var lastError: String?
    var isReachable: Bool

    var subjectCN: String?
    var issuerCN: String?
    var validFrom: Date?
    var validUntil: Date?
    var sanSummary: String?
    var pemData: Data?
    var serialNumber: String?
    var signatureAlgorithm: String?
    var publicKeyDescription: String?
    var chainPEMData: Data?

    init(
        id: UUID = UUID(),
        hostname: String,
        port: Int,
        displayName: String? = nil,
        tag: String? = nil,
        notes: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.hostname = hostname
        self.port = port
        self.displayName = displayName
        self.tag = tag
        self.notes = notes
        self.createdAt = createdAt
        self.isReachable = false
    }

    var title: String {
        if let displayName, !displayName.isEmpty {
            return displayName
        }
        return hostname
    }

    var hostPortLabel: String {
        port == 443 ? hostname : "\(hostname):\(port)"
    }

    var subjectAlternativeNames: [String] {
        guard let sanSummary, !sanSummary.isEmpty else { return [] }
        return sanSummary.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    func apply(certificate: CertificateInfo, checkedAt: Date = .now) {
        let leaf = certificate.leaf
        isReachable = true
        lastError = nil
        lastCheckedAt = checkedAt
        subjectCN = leaf.subjectCommonName
        issuerCN = leaf.issuerCommonName
        validFrom = leaf.validFrom
        validUntil = leaf.validUntil
        sanSummary = leaf.subjectAlternativeNames.joined(separator: ", ")
        pemData = leaf.pemRepresentation.data(using: .utf8)
        serialNumber = leaf.serialNumber
        signatureAlgorithm = leaf.signatureAlgorithm
        publicKeyDescription = leaf.publicKeyDescription

        if !certificate.chain.isEmpty {
            let joined = certificate.chain.map(\.pemRepresentation).joined(separator: "\n")
            chainPEMData = joined.data(using: .utf8)
        } else {
            chainPEMData = leaf.pemRepresentation.data(using: .utf8)
        }
    }

    func apply(error: String, checkedAt: Date = .now) {
        isReachable = false
        lastError = error
        lastCheckedAt = checkedAt
    }

    var pemRepresentation: String? {
        guard let pemData else { return nil }
        return String(data: pemData, encoding: .utf8)
    }
}

extension MonitoredEndpoint {
    static func sortByExpiry(_ endpoints: [MonitoredEndpoint]) -> [MonitoredEndpoint] {
        endpoints.sorted { lhs, rhs in
            switch (lhs.validUntil, rhs.validUntil) {
            case let (l?, r?):
                if l == r { return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending }
                return l < r
            case (nil, nil):
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            case (nil, _?):
                return false
            case (_?, nil):
                return true
            }
        }
    }
}
