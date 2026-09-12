import SwiftData
import XCTest
@testable import CertWatch

private struct MockCertificateFetcher: CertificateFetching {
    enum Behavior {
        case success(CertificateInfo)
        case failure(Error)
    }

    let behavior: Behavior

    func fetchCertificateChain(host: String, port: Int) async throws -> CertificateInfo {
        switch behavior {
        case .success(let certificate):
            return certificate
        case .failure(let error):
            throw error
        }
    }
}

@MainActor
final class EndpointStoreAddTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try ModelContainer(
            for: MonitoredEndpoint.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
    }

    override func tearDown() {
        container = nil
        context = nil
        super.tearDown()
    }

    func testAddEndpointDoesNotPersistWhenFetchFails() async throws {
        let store = EndpointStore(
            modelContext: context,
            certificateService: MockCertificateFetcher(behavior: .failure(CertificateService.CertError.timeout))
        )

        do {
            _ = try await store.addEndpoint(hostname: "unreachable.test", port: 443)
            XCTFail("Expected timeout error")
        } catch {
            XCTAssertEqual(error as? CertificateService.CertError, .timeout)
        }

        XCTAssertEqual(try store.fetchAll().count, 0)
    }

    func testAddEndpointPersistsWhenFetchSucceeds() async throws {
        let store = EndpointStore(
            modelContext: context,
            certificateService: MockCertificateFetcher(behavior: .success(CertificateInfo.preview()))
        )

        let endpoint = try await store.addEndpoint(hostname: "api.example.com", port: 443)

        XCTAssertEqual(try store.fetchAll().count, 1)
        XCTAssertEqual(endpoint.hostname, "api.example.com")
        XCTAssertTrue(endpoint.isReachable)
        XCTAssertEqual(endpoint.subjectCN, "api.example.com")
    }
}
