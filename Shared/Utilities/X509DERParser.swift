import Foundation

enum X509DERParser {
    struct Fields: Sendable {
        var validFrom: Date?
        var validUntil: Date?
        var issuerCommonName: String?
        var subjectAlternativeNames: [String]
        var signatureAlgorithm: String?
    }

    static func parseFields(from data: Data) -> Fields {
        var fields = Fields(subjectAlternativeNames: [])
        var reader = DERReader(data: data)

        guard reader.readTag() == .sequence,
              reader.readLength() != nil,
              reader.readTag() == .sequence,
              reader.readLength() != nil else {
            return fields
        }

        if reader.readTag() == .contextSpecific0 {
            _ = reader.readLength()
            _ = reader.readElement()
        }

        _ = reader.readElement()

        if let algorithm = reader.readAlgorithmIdentifier() {
            fields.signatureAlgorithm = algorithm
        }

        if let issuerCN = reader.readNameCommonName() {
            fields.issuerCommonName = issuerCN
        }

        if let validity = reader.readValidity() {
            fields.validFrom = validity.from
            fields.validUntil = validity.until
        }

        _ = reader.readNameCommonName()

        _ = reader.readElement()
        _ = reader.readElement()

        if reader.readTag() == .contextSpecific3 {
            _ = reader.readLength()
            if let extensions = reader.readExtensions() {
                fields.subjectAlternativeNames = extensions
            }
        }

        return fields
    }

    static func commonName(fromDN data: Data) -> String? {
        var reader = DERReader(data: data)
        return reader.readNameCommonName()
    }

    private struct Validity {
        let from: Date
        let until: Date
    }

    private enum DERTag: UInt8 {
        case boolean = 0x01
        case integer = 0x02
        case bitString = 0x03
        case octetString = 0x04
        case null = 0x05
        case objectIdentifier = 0x06
        case utf8String = 0x0C
        case printableString = 0x13
        case ia5String = 0x16
        case utcTime = 0x17
        case generalizedTime = 0x18
        case sequence = 0x30
        case set = 0x31
        case contextSpecific0 = 0xA0
        case contextSpecific3 = 0xA3

        init?(rawValue: UInt8) {
            switch rawValue {
            case 0x01: self = .boolean
            case 0x02: self = .integer
            case 0x03: self = .bitString
            case 0x04: self = .octetString
            case 0x05: self = .null
            case 0x06: self = .objectIdentifier
            case 0x0C: self = .utf8String
            case 0x13: self = .printableString
            case 0x16: self = .ia5String
            case 0x17: self = .utcTime
            case 0x18: self = .generalizedTime
            case 0x30: self = .sequence
            case 0x31: self = .set
            case 0xA0: self = .contextSpecific0
            case 0xA3: self = .contextSpecific3
            default: return nil
            }
        }
    }

    private struct DERReader {
        let data: Data
        var offset = 0

        mutating func readTag() -> DERTag? {
            guard offset < data.count, let tag = DERTag(rawValue: data[offset]) else { return nil }
            offset += 1
            return tag
        }

        mutating func readLength() -> Int? {
            guard offset < data.count else { return nil }
            let first = Int(data[offset])
            offset += 1

            if first & 0x80 == 0 {
                return first
            }

            let byteCount = first & 0x7F
            guard byteCount > 0, byteCount <= 4, offset + byteCount <= data.count else { return nil }

            var length = 0
            for _ in 0..<byteCount {
                length = (length << 8) | Int(data[offset])
                offset += 1
            }
            return length
        }

        mutating func readElement() -> Data? {
            guard let _ = readTag(), let length = readLength(), offset + length <= data.count else { return nil }
            let element = data[offset..<(offset + length)]
            offset += length
            return Data(element)
        }

        mutating func readAlgorithmIdentifier() -> String? {
            guard let body = readElement() else { return nil }
            var inner = DERReader(data: body)
            guard let oidData = inner.readElement() else { return nil }
            return Self.algorithmName(fromOID: oidData)
        }

        mutating func readNameCommonName() -> String? {
            guard let body = readElement() else { return nil }
            return Self.commonName(fromDN: body)
        }

        mutating func readValidity() -> Validity? {
            guard let body = readElement() else { return nil }
            var inner = DERReader(data: body)
            guard let from = inner.readTime(),
                  let until = inner.readTime() else {
                return nil
            }
            return Validity(from: from, until: until)
        }

        mutating func readTime() -> Date? {
            guard let tag = readTag(), let length = readLength(), offset + length <= data.count else { return nil }
            let value = String(decoding: data[offset..<(offset + length)], as: UTF8.self)
            offset += length

            switch tag {
            case .utcTime:
                return Self.parseUTCTime(value)
            case .generalizedTime:
                return Self.parseGeneralizedTime(value)
            default:
                return nil
            }
        }

        mutating func readExtensions() -> [String]? {
            guard let body = readElement() else { return nil }
            var inner = DERReader(data: body)
            var sans: [String] = []

            while inner.offset < inner.data.count {
                guard let extensionBody = inner.readElement() else { break }
                var extensionReader = DERReader(data: extensionBody)
                guard let oidData = extensionReader.readElement(),
                      Self.oidString(fromOID: oidData) == "2.5.29.17" else {
                    continue
                }

                if extensionReader.readTag() == .boolean {
                    _ = extensionReader.readLength()
                    extensionReader.offset += 1
                }

                guard let value = extensionReader.readElement() else { continue }
                sans.append(contentsOf: Self.subjectAlternativeNames(fromExtensionValue: value))
            }

            return sans.isEmpty ? nil : sans
        }

        private static func commonName(fromDN body: Data) -> String? {
            var reader = DERReader(data: body)
            while reader.offset < reader.data.count {
                guard let rdn = reader.readElement() else { break }
                var setReader = DERReader(data: rdn)
                guard let attribute = setReader.readElement() else { continue }
                var attributeReader = DERReader(data: attribute)
                guard let oidData = attributeReader.readElement(),
                      oidString(fromOID: oidData) == "2.5.4.3",
                      let valueData = attributeReader.readElement(),
                      let value = string(from: valueData) else {
                    continue
                }
                return value
            }
            return nil
        }

        private static func subjectAlternativeNames(fromExtensionValue value: Data) -> [String] {
            var reader = DERReader(data: value)
            guard let body = reader.readElement() else { return [] }

            var namesReader = DERReader(data: body)
            var names: [String] = []

            while namesReader.offset < namesReader.data.count {
                guard let tagByte = namesReader.data[safe: namesReader.offset],
                      let tag = DERTag(rawValue: tagByte) else { break }

                if tag == .contextSpecific0 || tagByte == 0x82 {
                    namesReader.offset += 1
                    guard let length = namesReader.readLength(),
                          namesReader.offset + length <= namesReader.data.count else { break }
                    let nameData = namesReader.data[namesReader.offset..<(namesReader.offset + length)]
                    namesReader.offset += length
                    if tagByte == 0x82, let name = string(from: Data(nameData)) {
                        names.append(name)
                    }
                } else {
                    _ = namesReader.readElement()
                }
            }

            return names
        }

        private static func parseUTCTime(_ value: String) -> Date? {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)

            if value.count == 13 {
                formatter.dateFormat = "yyMMddHHmmss'Z'"
                return formatter.date(from: value)
            }
            if value.count == 11 {
                formatter.dateFormat = "yyMMddHHmm'Z'"
                return formatter.date(from: value)
            }
            return nil
        }

        private static func parseGeneralizedTime(_ value: String) -> Date? {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)

            if value.hasSuffix("Z") {
                formatter.dateFormat = value.count == 15 ? "yyyyMMddHHmmss'Z'" : "yyyyMMddHHmm'Z'"
                return formatter.date(from: value)
            }
            return nil
        }

        private static func string(from data: Data) -> String? {
            String(decoding: data, as: UTF8.self)
        }

        private static func oidString(fromOID data: Data) -> String? {
            guard data.count >= 2 else { return nil }
            var parts = [Int(data[0] / 40), Int(data[0] % 40)]
            var value = 0
            for byte in data.dropFirst() {
                if byte & 0x80 != 0 {
                    value = (value << 7) | Int(byte & 0x7F)
                } else {
                    value = (value << 7) | Int(byte)
                    parts.append(value)
                    value = 0
                }
            }
            return parts.map(String.init).joined(separator: ".")
        }

        private static func algorithmName(fromOID data: Data) -> String? {
            switch oidString(fromOID: data) {
            case "1.2.840.113549.1.1.11": return "SHA-256 with RSA Encryption"
            case "1.2.840.113549.1.1.13": return "SHA-512 with RSA Encryption"
            case "1.2.840.113549.1.1.5": return "SHA-1 with RSA Encryption"
            case "1.2.840.10045.4.3.2": return "ECDSA with SHA-256"
            case "1.2.840.10045.4.3.3": return "ECDSA with SHA-384"
            case "1.2.840.10045.4.3.4": return "ECDSA with SHA-512"
            default: return oidString(fromOID: data).map { "OID \($0)" }
            }
        }
    }
}

private extension Data {
    subscript(safe index: Int) -> UInt8? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
