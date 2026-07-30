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

  func testDeterministicCborRejectsNonMinimalArgumentsForEveryApplicableMajorType() {
    for hex in [
      "1817",  // unsigned integer
      "3817",  // negative integer
      "5800",  // byte string length
      "7800",  // text string length
      "9800",  // array length
      "b800",  // map length
      "d80000",  // tag number
    ] {
      XCTAssertThrowsError(
        try CborScanner(data: Data(hex: hex), options: .deterministicCbor).scan(), hex)
    }
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

  func testDeterministicCborRejectsEveryIndefiniteLengthItem() {
    for hex in [
      "5fff",  // byte string
      "7fff",  // text string
      "9fff",  // array
      "bfff",  // map
      "819fff",  // nested array
    ] {
      XCTAssertThrowsError(
        try CborScanner(data: Data(hex: hex), options: .deterministicCbor).scan(), hex)
    }
  }

  func testLexicographicallySortedMapKeysRejectsUnsortedMapsRecursively() throws {
    let decoder = CborDecoder(options: .lexicographicallySortedMapKeys)

    XCTAssertThrowsError(
      try decoder.decode([String: Int].self, from: Data(hex: "a2616201616102")))
    XCTAssertThrowsError(
      try decoder.decode([String: [String: Int]].self, from: Data(hex: "a16161a2616201616102")))
    XCTAssertThrowsError(
      try decoder.decode([String: Int].self, from: Data(hex: "bf616201616102ff")))
  }

  func testLexicographicallySortedMapKeysAllowsSortedKeys() throws {
    let options = CborDecoder.Options.lexicographicallySortedMapKeys

    XCTAssertNoThrow(
      try CborDecoder(options: options).decode(
        [String: Int].self, from: Data(hex: "a2616101616202")))
  }

  func testLexicographicallySortedMapKeysDoesNotValidateDuplicateKeys() throws {
    let options = CborDecoder.Options.lexicographicallySortedMapKeys

    XCTAssertNoThrow(try CborScanner(data: Data(hex: "a2616101616102"), options: options).scan())
  }

  func testDeterministicCborUsesRfc8949BytewiseMapKeyOrder() throws {
    let coreOrder = Data(
      hex: "a80af61864f620f6617af6626161f6811864f68120f6f4f6")
    let lengthFirstOrder = Data(
      hex: "a80af620f6f4f61864f6617af68120f6626161f6811864f6")

    XCTAssertNoThrow(try CborScanner(data: coreOrder, options: .deterministicCbor).scan())
    XCTAssertThrowsError(
      try CborScanner(data: lengthFirstOrder, options: .deterministicCbor).scan())
  }

  func testDeterministicCborValidatesMapOrderWithinCompositeKeys() {
    XCTAssertThrowsError(
      try CborScanner(
        data: Data(hex: "a1a261620061610000"), options: .deterministicCbor
      ).scan())
  }

  func testDefaultDecoderAcceptsUnsortedMapKeys() throws {
    XCTAssertEqual(
      try CborDecoder().decode([String: Int].self, from: Data(hex: "a2616201616102")),
      ["a": 2, "b": 1])
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

  func testShortestFloatingPointEncodingSelectsSmallestExactWidth() throws {
    let encoder = CborEncoder(options: .shortestFloatingPointEncoding)

    XCTAssertEqual(try encoder.encode(Double(1.5)).hexDescription, "f93e00")
    XCTAssertEqual(try encoder.encode(Double(1.1)).hexDescription, "fb3ff199999999999a")
    XCTAssertEqual(try encoder.encode(Double(65_504)).hexDescription, "f97bff")
    XCTAssertEqual(try encoder.encode(Double(100_000)).hexDescription, "fa47c35000")
    XCTAssertEqual(try encoder.encode(Double(1_000_000.5)).hexDescription, "fa49742408")
    XCTAssertEqual(try encoder.encode(Double(5.960464477539063e-8)).hexDescription, "f90001")
    XCTAssertEqual(try encoder.encode(Double(0.00006103515625)).hexDescription, "f90400")
    XCTAssertEqual(
      try encoder.encode(Double.greatestFiniteMagnitude).hexDescription,
      "fb7fefffffffffffff")
  }

  func testShortestFloatingPointEncodingHandlesSpecialValues() throws {
    let encoder = CborEncoder(options: .shortestFloatingPointEncoding)

    XCTAssertEqual(try encoder.encode(Double.zero).hexDescription, "f90000")
    XCTAssertEqual(try encoder.encode(-Double.zero).hexDescription, "f98000")
    XCTAssertEqual(try encoder.encode(Double.infinity).hexDescription, "f97c00")
    XCTAssertEqual(try encoder.encode(-Double.infinity).hexDescription, "f9fc00")
    XCTAssertEqual(try encoder.encode(Double.nan).hexDescription, "f97e00")
    XCTAssertEqual(
      try encoder.encode(Float(bitPattern: 0xFFC0_0000)).hexDescription,
      "f9fe00")
  }

  func testShortestFloatingPointEncodingPreservesNaNRepresentations() throws {
    let encoder = CborEncoder(options: .shortestFloatingPointEncoding)

    XCTAssertEqual(
      try encoder.encode(Float16(bitPattern: 0x7D01)).hexDescription,
      "f97d01")
    XCTAssertEqual(
      try encoder.encode(Float(bitPattern: 0xFFC1_2345)).hexDescription,
      "faffc12345")
    XCTAssertEqual(
      try encoder.encode(Double(bitPattern: 0x7FF8_0000_2000_0000)).hexDescription,
      "fa7fc00001")
    XCTAssertEqual(
      try encoder.encode(Double(bitPattern: 0x7FF8_0000_0000_0001)).hexDescription,
      "fb7ff8000000000001")
  }

  func testShortestFloatingPointEncodingPreservesEveryFloat16BitPattern() throws {
    let encoder = CborEncoder(options: .shortestFloatingPointEncoding)

    for bitPattern in UInt16.min...UInt16.max {
      let expected = Data([
        0xF9,
        UInt8(truncatingIfNeeded: bitPattern >> 8),
        UInt8(truncatingIfNeeded: bitPattern),
      ])
      let actual = try encoder.encode(Float16(bitPattern: bitPattern))
      if actual != expected {
        XCTFail(
          "Float16 bit pattern \(String(bitPattern, radix: 16)) encoded as \(actual.hexDescription)"
        )
        return
      }
    }
  }

  func testDefaultEncoderPreservesFloatingPointSourceWidth() throws {
    let encoder = CborEncoder()

    XCTAssertEqual(try encoder.encode(Float16(1.5)).hexDescription, "f93e00")
    XCTAssertEqual(try encoder.encode(Float(1.5)).hexDescription, "fa3fc00000")
    XCTAssertEqual(try encoder.encode(Double(1.5)).hexDescription, "fb3ff8000000000000")
  }

  func testShortestFloatingPointDecodingRejectsValuesThatCanNarrow() {
    let decoder = CborDecoder(options: .shortestFloatingPointEncoding)

    for hex in [
      "fa3fc00000",  // 1.5 as Float32
      "fb3ff8000000000000",  // 1.5 as Float64
      "fa00000000",  // positive zero as Float32
      "fa7f800000",  // infinity as Float32
      "fb0000000000000000",  // positive zero as Float64
      "fb8000000000000000",  // negative zero as Float64
      "fb7ff0000000000000",  // infinity as Float64
      "fbfff0000000000000",  // -infinity as Float64
      "fa80000000",  // negative zero as Float32
      "fa33800000",  // the smallest Float16 subnormal as Float32
      "fb36a0000000000000",  // the smallest Float32 subnormal as Float64
      "fa7fc02000",  // NaN with a payload that fits in Float16
      "faffc02000",  // negative NaN with a payload that fits in Float16
      "fb7ff8000020000000",  // NaN with a payload that fits in Float32
    ] {
      XCTAssertThrowsError(try decoder.decode(Double.self, from: Data(hex: hex)), hex)
    }
  }

  func testShortestFloatingPointDecodingAcceptsValuesThatCannotNarrow() throws {
    let decoder = CborDecoder(options: .shortestFloatingPointEncoding)

    XCTAssertEqual(
      try decoder.decode(Float.self, from: Data(hex: "fa3f8ccccd")),
      Float(bitPattern: 0x3F8C_CCCD))
    XCTAssertEqual(
      try decoder.decode(Double.self, from: Data(hex: "fb3ff199999999999a")), 1.1)
    XCTAssertEqual(
      try decoder.decode(Float.self, from: Data(hex: "fa00000001")).bitPattern, 1)
    XCTAssertEqual(
      try decoder.decode(Double.self, from: Data(hex: "fb0000000000000001")).bitPattern, 1)
    XCTAssertTrue(
      try decoder.decode(Float.self, from: Data(hex: "faffc12345")).isNaN)
    XCTAssertTrue(
      try decoder.decode(Float.self, from: Data(hex: "fa7f800001")).isNaN)
    XCTAssertTrue(
      try decoder.decode(Double.self, from: Data(hex: "fb7ff8000000000001")).isNaN)
    XCTAssertTrue(
      try decoder.decode(Double.self, from: Data(hex: "fb7ff0000000000001")).isNaN)
  }

  func testShortestFloatingPointDecodingAcceptsEveryFloat16BitPattern() throws {
    let options = CborDecoder.Options.shortestFloatingPointEncoding

    for bitPattern in UInt16.min...UInt16.max {
      let data = Data([
        0xF9,
        UInt8(truncatingIfNeeded: bitPattern >> 8),
        UInt8(truncatingIfNeeded: bitPattern),
      ])
      XCTAssertNoThrow(try CborScanner(data: data, options: options).scan())
    }
  }

  func testDefaultDecoderAcceptsNonShortestFloatingPointEncoding() throws {
    XCTAssertEqual(
      try CborDecoder().decode(Double.self, from: Data(hex: "fb3ff8000000000000")), 1.5)
  }

  func testShortestFloatingPointEncodingCombinesWithRecursiveMapSorting() throws {
    let options: CborEncoder.Options = [
      .lexicographicallySortedMapKeys,
      .shortestFloatingPointEncoding,
    ]
    let encoder = CborEncoder(options: options)

    XCTAssertEqual(
      try encoder.encode([
        "b": [Double(2)],
        "a": [Double(1.5)],
      ]).hexDescription,
      "a2616181f93e00616281f94000")
  }

  func testDeterministicCborContainsCoreOptions() {
    XCTAssertTrue(CborEncoder.Options.deterministicCbor.contains(.lexicographicallySortedMapKeys))
    XCTAssertTrue(CborEncoder.Options.deterministicCbor.contains(.shortestFloatingPointEncoding))
    XCTAssertTrue(CborDecoder.Options.deterministicCbor.contains(.minimalArgumentEncoding))
    XCTAssertTrue(CborDecoder.Options.deterministicCbor.contains(.definiteLengthItems))
    XCTAssertTrue(
      CborDecoder.Options.deterministicCbor.contains(.lexicographicallySortedMapKeys))
    XCTAssertTrue(
      CborDecoder.Options.deterministicCbor.contains(.shortestFloatingPointEncoding))
  }

  func testDeterministicCborIntegratesCoreRules() throws {
    let encoder = CborEncoder(options: .deterministicCbor)
    let input = ["b": 2.0, "a": 1.5]
    let encoded = try encoder.encode(input)
    XCTAssertEqual(
      encoded.hexDescription, "a26161f93e006162f94000")

    let decoder = CborDecoder(options: .deterministicCbor)
    XCTAssertEqual(try decoder.decode([String: Double].self, from: encoded), input)
    XCTAssertThrowsError(try decoder.decode(UInt8.self, from: Data(hex: "1817")))
    XCTAssertThrowsError(try decoder.decode([Int].self, from: Data(hex: "9f01ff")))
    XCTAssertThrowsError(
      try decoder.decode([String: Int].self, from: Data(hex: "a2616201616102")))
    XCTAssertThrowsError(try decoder.decode(Double.self, from: Data(hex: "fa3fc00000")))
  }

  func testStringMapKeysOnlyRejectsOtherKeyTypes() {
    let decoder = CborDecoder(options: .stringMapKeysOnly)
    XCTAssertThrowsError(try decoder.decode([String: Int].self, from: Data(hex: "a10102")))
  }

  func testStringMapKeysOnlyAcceptsTextKeys() throws {
    let decoder = CborDecoder(options: .stringMapKeysOnly)
    XCTAssertEqual(try decoder.decode([String: Int].self, from: Data(hex: "a1616101")), ["a": 1])
  }

  func testMajorType7SimpleValuesAreNotIntegers() {
    let decoder = CborDecoder()
    XCTAssertThrowsError(try decoder.decode(Int.self, from: Data(hex: "f0")))
    XCTAssertThrowsError(try decoder.decode(Int.self, from: Data(hex: "f3")))
    XCTAssertThrowsError(try decoder.decode(Int.self, from: Data(hex: "f820")))
  }

  func testDefaultDecoderKeepsUndefinedAsNull() throws {
    XCTAssertNil(try CborDecoder().decode(String?.self, from: Data(hex: "f7")))
  }

  func testBasicSimpleValuesOnlyRejectsUndefinedAndOtherSimpleValues() {
    let decoder = CborDecoder(options: .basicSimpleValuesOnly)
    XCTAssertThrowsError(try decoder.decode(String?.self, from: Data(hex: "f7")))
    XCTAssertThrowsError(try decoder.decode(Int.self, from: Data(hex: "f0")))
    XCTAssertThrowsError(try decoder.decode(Int.self, from: Data(hex: "f820")))
  }

  func testBasicSimpleValuesOnlyAcceptsBoolAndNull() throws {
    let decoder = CborDecoder(options: .basicSimpleValuesOnly)
    XCTAssertEqual(try decoder.decode(Bool.self, from: Data(hex: "f4")), false)
    XCTAssertEqual(try decoder.decode(Bool.self, from: Data(hex: "f5")), true)
    XCTAssertNil(try decoder.decode(String?.self, from: Data(hex: "f6")))
  }

  func testFiniteFloatingPointValuesOnlyRejectsNonFiniteValues() {
    let encoder = CborEncoder(options: .finiteFloatingPointValuesOnly)
    XCTAssertThrowsError(try encoder.encode(Double.nan))
    XCTAssertThrowsError(try encoder.encode(Double.infinity))
    XCTAssertThrowsError(try encoder.encode(-Double.infinity))

    let decoder = CborDecoder(options: .finiteFloatingPointValuesOnly)
    XCTAssertThrowsError(try decoder.decode(Float16.self, from: Data(hex: "f97e00")))
    XCTAssertThrowsError(try decoder.decode(Float.self, from: Data(hex: "fa7f800000")))
    XCTAssertThrowsError(try decoder.decode(Double.self, from: Data(hex: "fbfff0000000000000")))
  }

  func testFiniteFloatingPointValuesOnlyAcceptsEveryFiniteWidth() throws {
    let decoder = CborDecoder(options: .finiteFloatingPointValuesOnly)
    XCTAssertEqual(try decoder.decode(Float16.self, from: Data(hex: "f93e00")), 1.5)
    XCTAssertEqual(try decoder.decode(Float.self, from: Data(hex: "fa3fc00000")), 1.5)
    XCTAssertEqual(try decoder.decode(Double.self, from: Data(hex: "fb3ff8000000000000")), 1.5)
  }

  func testFiniteFloatingPointValuesOnlyAcceptsSignedZeroAndBoundaryValues() throws {
    let encoder = CborEncoder(options: .finiteFloatingPointValuesOnly)
    XCTAssertNoThrow(try encoder.encode(-0.0))
    XCTAssertNoThrow(try encoder.encode(Double.leastNonzeroMagnitude))
    XCTAssertNoThrow(try encoder.encode(Double.greatestFiniteMagnitude))
  }

  func testFiniteFloatingPointValuesOnlyRejectsSignalingNaN() {
    let encoder = CborEncoder(options: .finiteFloatingPointValuesOnly)
    XCTAssertThrowsError(try encoder.encode(Double.signalingNaN))
    XCTAssertThrowsError(try encoder.encode(Float.signalingNaN))
  }

  func testFiniteFloatingPointValuesOnlyRejectsFloat16NonFiniteValues() {
    let encoder = CborEncoder(options: .finiteFloatingPointValuesOnly)
    XCTAssertThrowsError(try encoder.encode(Float16.nan))
    XCTAssertThrowsError(try encoder.encode(Float16.infinity))
  }

  func testFiniteFloatingPointValuesOnlyCombinesWithShortestFloatingPointEncoding() throws {
    let encoder = CborEncoder(
      options: [.finiteFloatingPointValuesOnly, .shortestFloatingPointEncoding])
    XCTAssertEqual(try encoder.encode(Double(1.5)).hexDescription, "f93e00")
    XCTAssertThrowsError(try encoder.encode(Double.nan))
  }

  func testFloatingPoint64OnlyAlwaysEncodesAsDouble() throws {
    let encoder = CborEncoder(options: .floatingPoint64Only)
    XCTAssertEqual(try encoder.encode(Float16(1.5)).hexDescription, "fb3ff8000000000000")
    XCTAssertEqual(try encoder.encode(Float(1.5)).hexDescription, "fb3ff8000000000000")
    XCTAssertEqual(try encoder.encode(Double(1.5)).hexDescription, "fb3ff8000000000000")
  }

  func testFloatingPoint64OnlyRejectsNarrowerInput() throws {
    let decoder = CborDecoder(options: .floatingPoint64Only)
    XCTAssertThrowsError(try decoder.decode(Float.self, from: Data(hex: "f93e00")))
    XCTAssertThrowsError(try decoder.decode(Float.self, from: Data(hex: "fa3fc00000")))
    XCTAssertEqual(try decoder.decode(Double.self, from: Data(hex: "fb3ff8000000000000")), 1.5)
  }

  func testFloatingPointEncodingOptionsConflict() {
    let encodingOptions: CborEncoder.Options = [
      .shortestFloatingPointEncoding, .floatingPoint64Only,
    ]
    XCTAssertThrowsError(try CborEncoder(options: encodingOptions).encode(1.5))

    let decodingOptions: CborDecoder.Options = [
      .shortestFloatingPointEncoding, .floatingPoint64Only,
    ]
    XCTAssertThrowsError(
      try CborDecoder(options: decodingOptions).decode(
        Double.self, from: Data(hex: "fb3ff8000000000000")))
  }

  func testFloatingPoint64OnlyRoundtripsBitIdentically() throws {
    let encoder = CborEncoder(options: .floatingPoint64Only)
    let decoder = CborDecoder(options: .floatingPoint64Only)
    for value in [1.5, -0.0, Double.leastNonzeroMagnitude, Double.greatestFiniteMagnitude] {
      let data = try encoder.encode(value)
      XCTAssertEqual(data.first, 0xFB)
      XCTAssertEqual(data.count, 9)
      XCTAssertEqual(try decoder.decode(Double.self, from: data), value)
    }
  }

  func testFloatingPoint64OnlyEncodesNonFiniteAsFloat64() throws {
    let encoder = CborEncoder(options: .floatingPoint64Only)
    XCTAssertEqual(try encoder.encode(Double.infinity).hexDescription, "fb7ff0000000000000")
    XCTAssertEqual(try encoder.encode(-Double.infinity).hexDescription, "fbfff0000000000000")
    XCTAssertEqual(try encoder.encode(Float16.infinity).hexDescription, "fb7ff0000000000000")
  }

  func testFloatingPoint64OnlyCombinesWithFiniteFloatingPointValuesOnly() throws {
    let encoder = CborEncoder(
      options: [.floatingPoint64Only, .finiteFloatingPointValuesOnly])
    XCTAssertEqual(try encoder.encode(Double(1.5)).hexDescription, "fb3ff8000000000000")
    XCTAssertThrowsError(try encoder.encode(Double.nan))
    XCTAssertThrowsError(try encoder.encode(Double.infinity))
  }

  func testAllowedTagsRestrictsTagsSymmetrically() throws {
    let valid = TestTaggedValue(tag: 42, payload: .bytes(Data([0, 1, 2])))
    let encoder = CborEncoder(allowedTags: [42])
    let data = try encoder.encode(valid)
    XCTAssertEqual(data.hexDescription, "d82a43000102")

    let decoder = CborDecoder(allowedTags: [42])
    XCTAssertNoThrow(try decoder.decode(TestBytesLink.self, from: data))

    XCTAssertThrowsError(try encoder.encode(TestTaggedValue(tag: 1, payload: .integer(0))))
    XCTAssertThrowsError(try decoder.decode(TestBytesLink.self, from: Data(hex: "c100")))
  }

  func testAllowedTagsDefaultAllowsAnyTag() throws {
    let data = try CborEncoder().encode(TestTaggedValue(tag: 99, payload: .integer(0)))
    XCTAssertEqual(data.hexDescription, "d86300")
    XCTAssertNoThrow(try CborDecoder().decode(TestBytesLink.self, from: Data(hex: "d82a43000102")))
  }

  func testAllowedTagsEmptySetRejectsAllTaggedValues() {
    let encoder = CborEncoder(allowedTags: [])
    XCTAssertThrowsError(try encoder.encode(TestTaggedValue(tag: 42, payload: .integer(0))))

    let decoder = CborDecoder(allowedTags: [])
    XCTAssertThrowsError(try decoder.decode(TestBytesLink.self, from: Data(hex: "d82a43000102")))
  }

  func testDagCborAllowedTagsPresetIsTag42() {
    XCTAssertEqual(CborDecoder.dagCborAllowedTags, [42])
    XCTAssertEqual(CborEncoder.dagCborAllowedTags, [42])
  }

  func testCborCodableTypeValidatesItsOwnPayload() {
    let decoder = CborDecoder(allowedTags: [42])
    XCTAssertThrowsError(try decoder.decode(TestBytesLink.self, from: Data(hex: "d82a01")))
    XCTAssertThrowsError(try decoder.decode(TestBytesLink.self, from: Data(hex: "d82a4101")))
  }

  func testValidUTF8OnlyRejectsIllFormedText() {
    let decoder = CborDecoder(options: .validUTF8Only)
    XCTAssertThrowsError(try decoder.decode(String.self, from: Data(hex: "61ff")))
  }

  func testValidUTF8OnlyAcceptsValidText() throws {
    let decoder = CborDecoder(options: .validUTF8Only)
    XCTAssertEqual(try decoder.decode(String.self, from: Data(hex: "63e38182")), "あ")
  }
}

private struct TestTaggedValue: CborEncodable {
  enum Payload {
    case integer(Int)
    case bytes(Data)
  }
  let tag: UInt64
  let payload: Payload

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch payload {
    case .integer(let value): try container.encode(value)
    case .bytes(let value): try container.encode(value)
    }
  }
}

private struct TestBytesLink: CborDecodable {
  let bytes: Data
  var tag: UInt64 { 42 }

  init(from decoder: Decoder) throws {
    let raw = try decoder.singleValueContainer().decode(Data.self)
    guard raw.first == 0 else {
      throw DecodingError.dataCorrupted(
        .init(
          codingPath: decoder.codingPath,
          debugDescription: "DAG-CBOR link payload must start with 0x00."
        ))
    }
    bytes = raw
  }
}
