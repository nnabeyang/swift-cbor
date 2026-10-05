import XCTest

@testable import SwiftCbor

final class MisplacedBreakCodeTests: XCTestCase {
  private struct Ignored: Decodable {
    init(from decoder: Decoder) throws {}
  }

  func testBreakWhereDataItemIsRequiredThrows() throws {
    for options: CborDecoder.Options in [[], .deterministicCbor] {
      let decoder = CborDecoder(options: options)
      for hex in [
        "a100ff",  // definite map, value = break
        "a1ff00",  // definite map, key = break
        "81ff",  // definite array, element = break
        "8200ff",  // definite array, second element = break
        "c1ff",  // tag content = break
        "ff",  // top-level break
        "9f81ffff",  // definite array nested in an indefinite array
        "bf00ff",  // indefinite map, value = break
      ] {
        assertDataCorrupted(try decoder.decode(Ignored.self, from: Data(hex: hex)), hex)
      }
    }
  }

  func testMissingDataItemThrows() throws {
    let decoder = CborDecoder()
    for hex in ["", "81", "a1", "a100", "c1", "9f81", "bf00"] {
      assertDataCorrupted(try decoder.decode(Ignored.self, from: Data(hex: hex)), hex)
    }
  }

  func testReservedAdditionalInformationThrows() throws {
    let decoder = CborDecoder()
    for hex in ["fc", "fd", "fe", "81fc", "c1fc", "9ffcff"] {
      assertDataCorrupted(try decoder.decode(Ignored.self, from: Data(hex: hex)), hex)
    }
  }

  func testIndefiniteLengthItemsStillDecode() throws {
    let decoder = CborDecoder()
    XCTAssertEqual(try decoder.decode([Int].self, from: Data(hex: "9fff")), [])
    XCTAssertEqual(try decoder.decode([String: Int].self, from: Data(hex: "bfff")), [:])
    XCTAssertEqual(try decoder.decode([Int].self, from: Data(hex: "9f01ff")), [1])
    XCTAssertEqual(try decoder.decode(Data.self, from: Data(hex: "5f4101ff")), Data(hex: "01"))
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
