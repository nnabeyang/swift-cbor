import XCTest

@testable import SwiftCbor

final class IntegerKeyTests: XCTestCase {
  func testByteStringMapKeyThrowsDataCorrupted() throws {
    let decoder = CborDecoder()
    XCTAssertThrowsError(
      try decoder.decode([String: Int].self, from: Data(hex: "a1410102"))
    ) { error in
      guard case DecodingError.dataCorrupted = error else {
        XCTFail("Expected DecodingError.dataCorrupted, got \(error)")
        return
      }
    }
  }

  func testFloatMapKeyThrowsDataCorrupted() throws {
    let decoder = CborDecoder()
    XCTAssertThrowsError(
      try decoder.decode([String: Int].self, from: Data(hex: "a1f93e0002"))
    ) { error in
      guard case DecodingError.dataCorrupted = error else {
        XCTFail("Expected DecodingError.dataCorrupted, got \(error)")
        return
      }
    }
  }

  func testArrayMapKeyThrowsDataCorrupted() throws {
    let decoder = CborDecoder()
    XCTAssertThrowsError(
      try decoder.decode([String: Int].self, from: Data(hex: "a1810102"))
    ) { error in
      guard case DecodingError.dataCorrupted = error else {
        XCTFail("Expected DecodingError.dataCorrupted, got \(error)")
        return
      }
    }
  }
}
