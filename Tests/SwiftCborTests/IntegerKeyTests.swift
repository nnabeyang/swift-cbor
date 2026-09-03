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

  func testEncodeIntDictionaryUsesIntegerKeys() throws {
    let encoder = CborEncoder()
    let hex = try encoder.encode([1: "a"] as [Int: String]).hexDescription
    XCTAssertEqual(hex, "a1016161")
  }

  func testEncodeNegativeIntDictionaryUsesMajorType1() throws {
    let encoder = CborEncoder()
    let hex = try encoder.encode([-1: "a"] as [Int: String]).hexDescription
    XCTAssertEqual(hex, "a1206161")
  }

  func testRoundTripIntDictionary() throws {
    let encoder = CborEncoder()
    let decoder = CborDecoder()
    let input: [Int: String] = [1: "a", -1: "b", 255: "c"]
    let data = try encoder.encode(input)
    let output = try decoder.decode([Int: String].self, from: data)
    XCTAssertEqual(output, input)
  }

  func testEncodeStructWithIntCodingKey() throws {
    struct Sample: Codable, Equatable {
      let x: Int
      let y: Int
      enum CodingKeys: Int, CodingKey {
        case x = 1
        case y = -1
      }
    }
    let encoder = CborEncoder()
    let hex = try encoder.encode(Sample(x: 2, y: 3)).hexDescription
    XCTAssertEqual(hex, "a201022003")
  }

  func testRoundTripStructWithIntCodingKey() throws {
    struct Sample: Codable, Equatable {
      let x: Int
      let y: Int
      enum CodingKeys: Int, CodingKey {
        case x = 1
        case y = -1
      }
    }
    let encoder = CborEncoder()
    let decoder = CborDecoder()
    let input = Sample(x: 2, y: 3)
    let data = try encoder.encode(input)
    let output = try decoder.decode(Sample.self, from: data)
    XCTAssertEqual(output, input)
  }

  func testDecodeIntKeyedMapIntoStringDictionary() throws {
    let decoder = CborDecoder()
    let output = try decoder.decode([String: Int].self, from: Data(hex: "a10102"))
    XCTAssertEqual(output, ["1": 2])
  }

  func testDecodeTextKeyedMapIntoIntDictionary() throws {
    let decoder = CborDecoder()
    let output = try decoder.decode([Int: Int].self, from: Data(hex: "a1613102"))
    XCTAssertEqual(output, [1: 2])
  }

  func testCOSEKeyRoundTrip() throws {
    struct COSEKey: Codable, Equatable {
      let kty: Int
      let crv: Int
      let x: Data
      let y: Data
      enum CodingKeys: Int, CodingKey {
        case kty = 1
        case crv = -1
        case x = -2
        case y = -3
      }
    }
    let key = COSEKey(
      kty: 2,
      crv: 1,
      x: Data((0x00...0x1F).map { UInt8($0) }),
      y: Data((0x20...0x3F).map { UInt8($0) })
    )
    let expectedHex =
      "a4"
      + "0102"
      + "2001"
      + "215820" + "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"
      + "225820" + "202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f"
    let encoder = CborEncoder()
    let decoder = CborDecoder()
    let data = try encoder.encode(key)
    XCTAssertEqual(data.hexDescription, expectedHex)
    let output = try decoder.decode(COSEKey.self, from: data)
    XCTAssertEqual(output, key)
  }

  func testIntOverflowAsKeyThrowsDataCorrupted() throws {
    let decoder = CborDecoder()
    XCTAssertThrowsError(
      try decoder.decode([Int: Int].self, from: Data(hex: "a11bffffffffffffffff02"))
    ) { error in
      guard case DecodingError.dataCorrupted = error else {
        XCTFail("Expected DecodingError.dataCorrupted, got \(error)")
        return
      }
    }
  }
}
