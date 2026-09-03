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
