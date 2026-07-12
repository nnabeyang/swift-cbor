import XCTest

@testable import SwiftCbor

final class CborCodingOptionsTests: XCTestCase {
  func testOptionsDefaultToEmpty() {
    XCTAssertEqual(CborDecoder().options, [])
  }

  func testMinimalArgumentEncodingRejectsNonMinimalInteger() {
    let decoder = CborDecoder(options: .minimalArgumentEncoding)
    XCTAssertThrowsError(try decoder.decode(UInt8.self, from: Data(hex: "1817")))
  }

  func testMinimalArgumentEncodingAcceptsMinimalIntegerBoundaries() throws {
    let decoder = CborDecoder(options: .minimalArgumentEncoding)
    let cases: [(String, UInt64)] = [
      ("17", 23),
      ("1818", 24),
      ("18ff", 255),
      ("190100", 256),
      ("19ffff", 65_535),
      ("1a00010000", 65_536),
      ("1affffffff", UInt64(UInt32.max)),
      ("1b0000000100000000", UInt64(UInt32.max) + 1),
    ]

    for (hex, expected) in cases {
      XCTAssertEqual(try decoder.decode(UInt64.self, from: Data(hex: hex)), expected)
    }
  }

  func testMinimalArgumentEncodingRejectsNonMinimalIntegerWidths() {
    let decoder = CborDecoder(options: .minimalArgumentEncoding)
    for hex in [
      "1817",
      "1900ff",
      "1a0000ffff",
      "1b00000000ffffffff",
    ] {
      XCTAssertThrowsError(try decoder.decode(UInt64.self, from: Data(hex: hex)))
    }
  }

  func testMinimalArgumentEncodingValidatesNegativeIntegerAndTag() {
    let options = CborDecoder.Options.minimalArgumentEncoding
    XCTAssertThrowsError(
      try CborDecoder(options: options).decode(Int.self, from: Data(hex: "3817")))
    XCTAssertThrowsError(try CborScanner(data: Data(hex: "d81700"), options: options).scan())
  }

  func testMinimalArgumentEncodingRejectsNonMinimalLength() {
    let decoder = CborDecoder(options: .minimalArgumentEncoding)
    XCTAssertThrowsError(try decoder.decode(Data.self, from: Data(hex: "580100")))
    XCTAssertThrowsError(try decoder.decode([UInt8].self, from: Data(hex: "9800")))
    XCTAssertThrowsError(try decoder.decode([String: UInt8].self, from: Data(hex: "b800")))
  }

  func testDefaultDecoderAcceptsNonMinimalArgument() throws {
    XCTAssertEqual(try CborDecoder().decode(UInt8.self, from: Data(hex: "1817")), 23)
  }

}
