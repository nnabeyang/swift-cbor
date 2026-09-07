import XCTest

@testable import SwiftCbor

/// A `Dictionary` whose `Key` is neither `String` nor `Int` is encoded by the standard library
/// through an unkeyed container holding a flat `[key, value, key, value, ...]` sequence. These
/// tests pin down that such dictionaries still round-trip through CBOR maps (major type 5) with
/// the key encoded as an arbitrary CBOR data item, as allowed by RFC 8949 Section 3.1.
final class DictionaryKeyTests: XCTestCase {
  private let encoder = CborEncoder()
  private let decoder = CborDecoder()

  func testByteStringKeys() throws {
    let value: [Data: Int] = [Data(hex: "01"): 2]
    XCTAssertEqual(try encoder.encode(value).hexDescription, "a1410102")
    XCTAssertEqual(try decoder.decode([Data: Int].self, from: Data(hex: "a1410102")), value)
  }

  func testBoolKeys() throws {
    let value: [Bool: Int] = [true: 1]
    XCTAssertEqual(try encoder.encode(value).hexDescription, "a1f501")
    XCTAssertEqual(try decoder.decode([Bool: Int].self, from: Data(hex: "a1f501")), value)
  }

  func testDoubleKeys() throws {
    let value: [Double: Int] = [1.5: 1]
    XCTAssertEqual(try encoder.encode(value).hexDescription, "a1fb3ff800000000000001")
    XCTAssertEqual(try decoder.decode([Double: Int].self, from: Data(hex: "a1f93e0001")), value)
  }

  func testFixedWidthIntegerKeysOtherThanInt() throws {
    let value: [UInt8: Int] = [1: 2]
    XCTAssertEqual(try encoder.encode(value).hexDescription, "a10102")
    XCTAssertEqual(try decoder.decode([UInt8: Int].self, from: Data(hex: "a10102")), value)
  }

  func testStructKeys() throws {
    let value: [Pair: Int] = [Pair(a: 1, b: 2): 3]
    XCTAssertEqual(try encoder.encode(value).hexDescription, "a1a261610161620203")
    XCTAssertEqual(
      try decoder.decode([Pair: Int].self, from: Data(hex: "a1a261610161620203")), value)
  }

  func testTaggedKeys() throws {
    let value: [TaggedKey: Int] = [TaggedKey(a: 0x46): 1]
    XCTAssertEqual(try encoder.encode(value).hexDescription, "a1d82a184601")
    XCTAssertEqual(
      try decoder.decode([TaggedKey: Int].self, from: Data(hex: "a1d82a184601")), value)
  }

  func testNestedDictionaries() throws {
    let value: [Data: [Data: Int]] = [Data(hex: "01"): [Data(hex: "02"): 3]]
    XCTAssertEqual(try encoder.encode(value).hexDescription, "a14101a1410203")
    XCTAssertEqual(
      try decoder.decode([Data: [Data: Int]].self, from: Data(hex: "a14101a1410203")), value)
  }

  func testDictionaryAsStructProperty() throws {
    let value = ByteKeyedHolder(m: [Data(hex: "aa"): 7])
    XCTAssertEqual(try encoder.encode(value).hexDescription, "a1616da141aa07")
    XCTAssertEqual(
      try decoder.decode(ByteKeyedHolder.self, from: Data(hex: "a1616da141aa07")), value)
  }

  func testDictionaryInsideArray() throws {
    let value: [[Data: Int]] = [[Data(hex: "01"): 2]]
    XCTAssertEqual(try encoder.encode(value).hexDescription, "81a1410102")
    XCTAssertEqual(try decoder.decode([[Data: Int]].self, from: Data(hex: "81a1410102")), value)
  }

  func testEmptyDictionaryEncodesAsEmptyMap() throws {
    XCTAssertEqual(try encoder.encode([Data: Int]()).hexDescription, "a0")
    XCTAssertEqual(try decoder.decode([Data: Int].self, from: Data(hex: "a0")), [Data: Int]())
  }

  func testOptionalValues() throws {
    let value: [Data: Int?] = [Data(hex: "01"): nil]
    XCTAssertEqual(try encoder.encode(value).hexDescription, "a14101f6")
    XCTAssertEqual(try decoder.decode([Data: Int?].self, from: Data(hex: "a14101f6")), value)
  }

  func testIndefiniteLengthMap() throws {
    XCTAssertEqual(
      try decoder.decode([Data: Int].self, from: Data(hex: "bf410102ff")), [Data(hex: "01"): 2])
  }

  func testDeterministicEncodingSortsKeysBytewise() throws {
    let encoder = CborEncoder(options: .deterministicCbor)
    let value: [Data: Int] = [Data(hex: "02"): 1, Data(hex: "01"): 2, Data(hex: "0100"): 3]
    XCTAssertEqual(try encoder.encode(value).hexDescription, "a341010241020142010003")
  }

  func testDeterministicRoundTrip() throws {
    let encoder = CborEncoder(options: .deterministicCbor)
    let decoder = CborDecoder(options: .deterministicCbor)
    let value: [Data: [Data: Int]] = [Data(hex: "02"): [Data(hex: "09"): 1, Data(hex: "08"): 2]]
    let encoded = try encoder.encode(value)
    XCTAssertEqual(encoded.hexDescription, "a14102a2410802410901")
    XCTAssertEqual(try decoder.decode([Data: [Data: Int]].self, from: Data(encoded)), value)
  }

  func testArrayDoesNotDecodeAsDictionary() throws {
    XCTAssertThrowsError(
      try decoder.decode([Data: Int].self, from: Data(hex: "82410102"))
    ) { error in
      guard case DecodingError.typeMismatch = error else {
        XCTFail("Expected DecodingError.typeMismatch, got \(error)")
        return
      }
    }
  }

  /// A CBOR text string carries UTF-8 bytes, so it maps onto `Data` as well as onto `String`.
  /// A byte string maps only onto `Data`, which is why the reverse is a type mismatch.
  func testTextStringKeyDecodesAsByteStringKey() throws {
    XCTAssertEqual(
      try decoder.decode([Data: Int].self, from: Data(hex: "a1616101")), [Data("a".utf8): 1])
    XCTAssertThrowsError(
      try decoder.decode([String: Int].self, from: Data(hex: "a1410102"))
    ) { error in
      guard case DecodingError.dataCorrupted = error else {
        XCTFail("Expected DecodingError.dataCorrupted, got \(error)")
        return
      }
    }
  }

  func testKeyTypeMismatchSurfacesAsError() throws {
    XCTAssertThrowsError(
      try decoder.decode([Pair: Int].self, from: Data(hex: "a1616102"))
    ) { error in
      guard case DecodingError.typeMismatch = error else {
        XCTFail("Expected DecodingError.typeMismatch, got \(error)")
        return
      }
    }
  }
}

private struct Pair: Codable, Hashable {
  let a: Int
  let b: Int
}

private struct ByteKeyedHolder: Codable, Equatable {
  let m: [Data: Int]
}

private struct TaggedKey: Hashable {
  let a: UInt8
}

extension TaggedKey: CborCodable {
  var tag: UInt64 { 42 }

  init(from decoder: Decoder) throws {
    a = try decoder.singleValueContainer().decode(UInt8.self)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(a)
  }
}
