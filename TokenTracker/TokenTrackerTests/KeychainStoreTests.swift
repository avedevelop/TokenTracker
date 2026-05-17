import XCTest
@testable import TokenTracker

final class KeychainStoreTests: XCTestCase {
    override func setUp() {
        super.setUp()
        KeychainStore.delete()
    }

    func test_save_thenLoad_returnsValue() throws {
        try KeychainStore.save("test-session-key-abc")
        let loaded = KeychainStore.load()
        XCTAssertEqual(loaded, "test-session-key-abc")
    }

    func test_load_whenEmpty_returnsNil() {
        let loaded = KeychainStore.load()
        XCTAssertNil(loaded)
    }

    func test_delete_removesValue() throws {
        try KeychainStore.save("some-key")
        KeychainStore.delete()
        XCTAssertNil(KeychainStore.load())
    }

    func test_save_overwritesPreviousValue() throws {
        try KeychainStore.save("old-key")
        try KeychainStore.save("new-key")
        XCTAssertEqual(KeychainStore.load(), "new-key")
    }
}
