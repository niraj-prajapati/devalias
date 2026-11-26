import XCTest
@testable import DevAlias

final class QRCodeGeneratorTests: XCTestCase {
    func testGeneratesImageForURL() {
        let image = QRCodeGenerator.image(for: "http://192.168.1.10:49200", pixels: 128)
        XCTAssertNotNil(image)
        XCTAssertGreaterThan(image?.size.width ?? 0, 0)
    }

    func testEmptyStringReturnsNil() {
        XCTAssertNil(QRCodeGenerator.image(for: ""))
    }
}
