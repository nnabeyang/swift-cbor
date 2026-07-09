import XCTest

@testable import SwiftCbor

final class CborCodingOptionsTests: XCTestCase {
  func testOptionsDefaultToEmpty() {
    XCTAssertEqual(CborEncoder().options, [])
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

  func testDefiniteLengthItemsRejectsIndefiniteArray() {
    let decoder = CborDecoder(options: .definiteLengthItems)
    XCTAssertThrowsError(try decoder.decode([Int].self, from: Data(hex: "9f0102ff")))
  }

  func testDefiniteLengthItemsRejectsIndefiniteString() {
    let decoder = CborDecoder(options: .definiteLengthItems)
    XCTAssertThrowsError(try decoder.decode(String.self, from: Data(hex: "7f6161ff")))
  }

  func testDefaultDecoderAcceptsIndefiniteArray() throws {
    XCTAssertEqual(try CborDecoder().decode([Int].self, from: Data(hex: "9f0102ff")), [1, 2])
  }

  func testLexicographicallySortedMapKeysSortsRecursively() throws {
    let encoder = CborEncoder(options: .lexicographicallySortedMapKeys)
    let input = [
      "aa": ["d": 4, "c": 3],
      "b": ["f": 6, "e": 5],
    ]
    let data = try encoder.encode(input)

    XCTAssertEqual(
      data.hexDescription,
      "a26162a2616505616606626161a2616303616404")
    XCTAssertEqual(try CborDecoder().decode([String: [String: Int]].self, from: data), input)
  }

  func testLexicographicallySortedMapKeysHandlesEmptyAndSingleEntryMaps() throws {
    let encoder = CborEncoder(options: .lexicographicallySortedMapKeys)

    XCTAssertEqual(try encoder.encode([String: Int]()).hexDescription, "a0")
    XCTAssertEqual(try encoder.encode(["x": 1]).hexDescription, "a1617801")
  }

  func testLexicographicallySortedMapKeysUsesRfc8949BytewiseOrder() {
    let null = CborEncodedValue.literal([0xF6])
    let value = CborEncodedValue.map([
      .literal([0xF4]), null,
      .array([.literal([0x20])]), null,
      .literal([0x62, 0x61, 0x61]), null,
      .literal([0x18, 0x64]), null,
      .array([.literal([0x18, 0x64])]), null,
      .literal([0x61, 0x7A]), null,
      .literal([0x20]), null,
      .literal([0x0A]), null,
    ])
    let writer = CborValue.Writer(sortMapKeysLexicographically: true)

    XCTAssertEqual(
      Data(writer.writeValue(value)).hexDescription,
      "a80af61864f620f6617af6626161f6811864f68120f6f4f6")
  }

  func testLexicographicallySortedMapKeysSortsMapsWithinCompositeKeys() {
    let value = CborEncodedValue.map([
      .map([
        .literal([0x61, 0x62]), .literal([0x02]),
        .literal([0x61, 0x61]), .literal([0x01]),
      ]),
      .literal([0x00]),
    ])
    let writer = CborValue.Writer(sortMapKeysLexicographically: true)

    XCTAssertEqual(Data(writer.writeValue(value)).hexDescription, "a1a261610161620200")
  }
}
