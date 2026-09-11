import Foundation

extension MonitoredEndpoint {
    var chainCertificates: [CertificateInfo] {
        guard let chainPEMData,
              let text = String(data: chainPEMData, encoding: .utf8) else {
            return []
        }
        return CertificatePEMParser.parseMultiple(from: text)
    }
}
