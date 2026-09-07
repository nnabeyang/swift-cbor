import XCTest

@testable import SwiftCbor

final class IndefiniteLengthStringTests: XCTestCase {
  private let decoder = CborDecoder()

  func testByteStringChunksAreConcatenated() throws {
    XCTAssertEqual(
      try decoder.decode(Data.self, from: Data(hex: "5f41014102ff")).hexDescription, "0102")
    XCTAssertEqual(
      try decoder.decode(Data.self, from: Data(hex: "5f4401020304420506ff")).hexDescription,
      "010203040506")
  }

  func testTextStringChunksAreConcatenated() throws {
    XCTAssertEqual(try decoder.decode(String.self, from: Data(hex: "7f61616162ff")), "ab")
    XCTAssertEqual(
      try decoder.decode(String.self, from: Data(hex: "7f6548656c6c6f6620576f726c64ff")),
      "Hello World")
  }

  func testEmptyIndefiniteLengthStrings() throws {
    XCTAssertEqual(try decoder.decode(Data.self, from: Data(hex: "5fff")), Data())
    XCTAssertEqual(try decoder.decode(String.self, from: Data(hex: "7fff")), "")
  }

  func testChunkPayloadMayContainBreakByte() throws {
    XCTAssertEqual(
      try decoder.decode(Data.self, from: Data(hex: "5f42ffffff")).hexDescription, "ffff")
  }

  func testBreakIsConsumedInsideContainers() throws {
    XCTAssertEqual(
      try decoder.decode([Data].self, from: Data(hex: "825f4101ff5f4102ff")),
      [Data(hex: "01"), Data(hex: "02")])
    XCTAssertEqual(
      try decoder.decode([Data: Int].self, from: Data(hex: "a15f41014102ff02")),
      [Data(hex: "0102"): 2])
  }

  func testBytesConsumedIncludesBreak() throws {
    let (value, bytesConsumed) = try decoder.decodePrefix(
      Data.self, from: Data(hex: "5f4101ff02"))
    XCTAssertEqual(value.hexDescription, "01")
    XCTAssertEqual(bytesConsumed, 4)
  }

  func testChunkOfMismatchedMajorTypeThrows() throws {
    // Text string chunk inside an indefinite-length byte string.
    assertDataCorrupted(try decoder.decode(Data.self, from: Data(hex: "5f6161ff")))
    // Byte string chunk inside an indefinite-length text string.
    assertDataCorrupted(try decoder.decode(String.self, from: Data(hex: "7f4101ff")))
    // Any other major type.
    assertDataCorrupted(try decoder.decode(Data.self, from: Data(hex: "5f01ff")))
  }

  func testNestedIndefiniteLengthChunkThrows() throws {
    assertDataCorrupted(try decoder.decode(Data.self, from: Data(hex: "5f5f4101ffff")))
    assertDataCorrupted(try decoder.decode(String.self, from: Data(hex: "7f7f6161ffff")))
  }

  func testUnterminatedIndefiniteLengthStringThrows() throws {
    assertDataCorrupted(try decoder.decode(Data.self, from: Data(hex: "5f4101")))
    assertDataCorrupted(try decoder.decode(Data.self, from: Data(hex: "5f41")))
  }

  func testStringSizeLimitAppliesAcrossChunks() throws {
    let decoder = CborDecoder(limits: .init(maximumStringBytes: 3))
    XCTAssertEqual(
      try decoder.decode(Data.self, from: Data(hex: "5f41014102ff")).hexDescription, "0102")
    assertDataCorrupted(try decoder.decode(Data.self, from: Data(hex: "5f4101410241034104ff")))
  }

  func testDefiniteLengthItemsOptionStillRejectsChunkedStrings() throws {
    let decoder = CborDecoder(options: [.definiteLengthItems])
    assertDataCorrupted(try decoder.decode(Data.self, from: Data(hex: "5f4101ff")))
    assertDataCorrupted(try decoder.decode(String.self, from: Data(hex: "7f6161ff")))
  }

  private func assertDataCorrupted<T>(
    _ expression: @autoclosure () throws -> T, file: StaticString = #filePath, line: UInt = #line
  ) {
    XCTAssertThrowsError(try expression(), file: file, line: line) { error in
      guard case DecodingError.dataCorrupted = error else {
        XCTFail("Expected DecodingError.dataCorrupted, got \(error)", file: file, line: line)
        return
      }
    }
  }
}
