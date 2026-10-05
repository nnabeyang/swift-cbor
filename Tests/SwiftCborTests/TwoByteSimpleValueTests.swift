import XCTest

@testable import SwiftCbor

final class TwoByteSimpleValueTests: XCTestCase {
  private struct Ignored: Decodable {
    init(from decoder: Decoder) throws {}
  }

  func testTwoByteSimpleValueBelow32Throws() throws {
    for options: CborDecoder.Options in [[], .basicSimpleValuesOnly] {
      let decoder = CborDecoder(options: options)
      for hex in [
        "f800",
        "f814",  // would be false
        "f816",  // would be null
        "f81f",
      ] {
        assertDataCorrupted(try decoder.decode(Ignored.self, from: Data(hex: hex)), hex)
      }
    }
  }

  func testTwoByteSimpleValueBelow32ThrowsForTypedDecoding() throws {
    let decoder = CborDecoder()
    assertDataCorrupted(try decoder.decode(Bool.self, from: Data(hex: "f814")), "f814")
    assertDataCorrupted(try decoder.decode(String?.self, from: Data(hex: "f816")), "f816")
  }

  func testTwoByteSimpleValueFrom32StillDecodes() throws {
    let decoder = CborDecoder()
    XCTAssertNoThrow(try decoder.decode(Ignored.self, from: Data(hex: "f820")))
    XCTAssertNoThrow(try decoder.decode(Ignored.self, from: Data(hex: "f8ff")))

    let basicDecoder = CborDecoder(options: .basicSimpleValuesOnly)
    assertDataCorrupted(try basicDecoder.decode(Ignored.self, from: Data(hex: "f820")), "f820")
    assertDataCorrupted(try basicDecoder.decode(Ignored.self, from: Data(hex: "f8ff")), "f8ff")
  }

  func testOneByteBoolAndNullAreUnaffected() throws {
    for options: CborDecoder.Options in [[], .basicSimpleValuesOnly] {
      let decoder = CborDecoder(options: options)
      XCTAssertEqual(try decoder.decode(Bool.self, from: Data(hex: "f4")), false)
      XCTAssertEqual(try decoder.decode(Bool.self, from: Data(hex: "f5")), true)
      XCTAssertNil(try decoder.decode(String?.self, from: Data(hex: "f6")))
    }
  }

  private func assertDataCorrupted<T>(
    _ expression: @autoclosure () throws -> T, _ message: String,
    file: StaticString = #filePath, line: UInt = #line
  ) {
    XCTAssertThrowsError(try expression(), message, file: file, line: line) { error in
      guard case DecodingError.dataCorrupted = error else {
        XCTFail(
          "Expected DecodingError.dataCorrupted, got \(error) (\(message))", file: file, line: line)
        return
      }
    }
  }
}
