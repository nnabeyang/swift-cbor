@testable import SwiftCbor
import XCTest

final class EncodeTests: XCTestCase {
    private let encoder = CborEncoder()
    func testSimple() throws {
        XCTAssertEqual(try encoder.encode(false).hexDescription, "f4")
        XCTAssertEqual(try encoder.encode(true).hexDescription, "f5")
        XCTAssertEqual(try encoder.encode(String?.none).hexDescription, "f6")
    }

    func testFloat() throws {
        XCTAssertEqual(try encoder.encode(Float16.greatestFiniteMagnitude).hexDescription, "f97bff")
        XCTAssertEqual(try encoder.encode(Float.greatestFiniteMagnitude).hexDescription, "fa7f7fffff")
        XCTAssertEqual(try encoder.encode(Double.greatestFiniteMagnitude).hexDescription, "fb7fefffffffffffff")
        XCTAssertEqual(try encoder.encode(Float16.infinity).hexDescription, "f97c00")
        XCTAssertEqual(try encoder.encode(Float.infinity).hexDescription, "fa7f800000")
        XCTAssertEqual(try encoder.encode(Double.infinity).hexDescription, "fb7ff0000000000000")
        XCTAssertEqual(try encoder.encode(Float16.nan).hexDescription, "f97e00")
        XCTAssertEqual(try encoder.encode(Float.nan).hexDescription, "fa7fc00000")
        XCTAssertEqual(try encoder.encode(Double.nan).hexDescription, "fb7ff8000000000000")
    }

    func testStruct() throws {
        let data = try encoder.encode(All.value)
        let output = try CborDecoder().decode(All.self, from: data)
        XCTAssertEqual(output, All.value)
    }

    func testMap() throws {
        XCTAssertEqual(try encoder.encode([String: String]()).hexDescription, "a0")
        let input = [
            "one": UInt64(0x17),
            "two": UInt64(UInt8.max),
            "three": UInt64(UInt16.max),
            "four": UInt64(UInt32.max),
            "five": UInt64.max,
        ]
        let data = try encoder.encode(input)
        let output = try CborDecoder().decode([String: UInt64].self, from: data)
        XCTAssertEqual(output, input)
    }

    func testArray() {
        XCTAssertEqual(try encoder.encode([String]()).hexDescription, "80")
        XCTAssertEqual(try encoder.encode([1, 2, 3]).hexDescription, "83010203")
        XCTAssertEqual(try encoder.encode([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25]).hexDescription, "98190102030405060708090a0b0c0d0e0f101112131415161718181819")
        XCTAssertEqual(try encoder.encode([[1], [2, 3], [4, 5]]).hexDescription, "838101820203820405")
    }

    func testString() throws {
        XCTAssertEqual(try encoder.encode("").hexDescription, "60")
        XCTAssertEqual(try encoder.encode("a").hexDescription, "6161")
        XCTAssertEqual(try encoder.encode("Hello World").hexDescription, "6b48656c6c6f20576f726c64")
        XCTAssertEqual(try encoder.encode("こんにちは、世界").hexDescription, "7818e38193e38293e381abe381a1e381afe38081e4b896e7958c")
    }

    func testByteString() throws {
        XCTAssertEqual(try encoder.encode(Data(hex: "01020304")).hexDescription, "4401020304")
        XCTAssertEqual(try encoder.encode(Data("abcdefghijklmnopqrstuvwxyz".utf8)).hexDescription, "581a6162636465666768696a6b6c6d6e6f707172737475767778797a")
    }

    func testInt() throws {
        // positive
        XCTAssertEqual(try encoder.encode(Int8(0x17)).hexDescription, "17")
        XCTAssertEqual(try encoder.encode(Int8(0x18)).hexDescription, "1818")
        XCTAssertEqual(try encoder.encode(Int8.max).hexDescription, "187f")
        XCTAssertEqual(try encoder.encode(Int16.max).hexDescription, "197fff")
        XCTAssertEqual(try encoder.encode(Int32.max).hexDescription, "1a7fffffff")
        XCTAssertEqual(try encoder.encode(Int64.max).hexDescription, "1b7fffffffffffffff")
        // negative
        XCTAssertEqual(try encoder.encode(Int8(~0)).hexDescription, "20")
        XCTAssertEqual(try encoder.encode(Int8(~0x05)).hexDescription, "25")
        XCTAssertEqual(try encoder.encode(Int8(~0x17)).hexDescription, "37")
        XCTAssertEqual(try encoder.encode(Int8(~0x17) - 1).hexDescription, "3818")
        XCTAssertEqual(try encoder.encode(~Int16(UInt8.max)).hexDescription, "38ff")
        XCTAssertEqual(try encoder.encode(~Int16(UInt8.max) - 1).hexDescription, "390100")
        XCTAssertEqual(try encoder.encode(~Int32(UInt16.max)).hexDescription, "39ffff")
        XCTAssertEqual(try encoder.encode(~Int32(UInt16.max) - 1).hexDescription, "3a00010000")
        XCTAssertEqual(try encoder.encode(~Int64(UInt32.max)).hexDescription, "3affffffff")
        XCTAssertEqual(try encoder.encode(~Int64(UInt32.max) - 1).hexDescription, "3b0000000100000000")
        XCTAssertEqual(try encoder.encode(Int64.min).hexDescription, "3b7fffffffffffffff")
    }

    func testUInt() throws {
        XCTAssertEqual(try encoder.encode(UInt8.min).hexDescription, "00")
        XCTAssertEqual(try encoder.encode(UInt8(0x17)).hexDescription, "17")
        XCTAssertEqual(try encoder.encode(UInt8(0x18)).hexDescription, "1818")
        XCTAssertEqual(try encoder.encode(UInt8.max).hexDescription, "18ff")
        XCTAssertEqual(try encoder.encode(UInt16(UInt8.max) + 1).hexDescription, "190100")
        XCTAssertEqual(try encoder.encode(UInt16.max).hexDescription, "19ffff")
        XCTAssertEqual(try encoder.encode(UInt32(UInt16.max) + 1).hexDescription, "1a00010000")
        XCTAssertEqual(try encoder.encode(UInt32.max).hexDescription, "1affffffff")
        XCTAssertEqual(try encoder.encode(UInt64(UInt32.max) + 1).hexDescription, "1b0000000100000000")
        XCTAssertEqual(try encoder.encode(UInt64.max).hexDescription, "1bffffffffffffffff")
    }
}

struct All: Codable, Equatable {
    let bool: Bool
    let int: Int
    let int8: Int8
    let int16: Int16
    let int32: Int32
    let int64: Int64
    let uint: UInt
    let uint8: UInt8
    let uint16: UInt16
    let uint32: UInt32
    let uint64: UInt64
    let float16: Float16
    let float: Float
    let double: Double
    let string: String
    let stringM: String
    let map: [String: Small]
    let mapP: [String: Small?]
    let floatMap: [Float: String]
    let nilArray: [String]?
    let emptyArray: [Small]
    let bytes: Data
    let superCodable: SuperCodable
    let tagged: Opacity
}

extension All {
    static var value: All {
        .init(
            bool: true,
            int: -0x4B_6B34_ABCC,
            int8: -0x35,
            int16: -0x4B6B,
            int32: -0x4B6B34,
            int64: -0x4B_6B34_ABCC,
            uint: 0x4B_6B34_ABCC,
            uint8: 0x35,
            uint16: 0x4B6B,
            uint32: 0x4B6B34,
            uint64: 0x4B_6B34_ABCC,
            float16: 3.14,
            float: Float(Float16.greatestFiniteMagnitude) * 2.0,
            double: Double(Float.greatestFiniteMagnitude) * 2.0,
            string: "Hello",
            stringM: "こんにちは",
            map: ["17": Small(tag: "tag17"), "18": Small(tag: "tag18")],
            mapP: ["19": Small(tag: "tag19"), "20": nil],
            floatMap: [1.41: "sqrt(2)", 3.14: "pi"],
            nilArray: nil,
            emptyArray: [],
            bytes: Data([27, 28, 29]),
            superCodable: SuperCodable(name: "hello", index: 3),
            tagged: Opacity(a: 0x46)
        )
    }
}

class Small: Codable, Hashable {
    static func == (lhs: Small, rhs: Small) -> Bool {
        lhs.tag == rhs.tag
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(tag)
    }

    let tag: String
    init(tag: String) {
        self.tag = tag
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Self.CodingKeys.self)
        try container.encode(tag, forKey: .tag)
    }
}

class Name: Codable {
    let name: String
    init(name: String) {
        self.name = name
    }

    private enum CodingKeys: String, CodingKey {
        case name
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Self.CodingKeys.self)
        try container.encode(name, forKey: .name)
    }
}

class SuperCodable: Name {
    let index: Int

    private enum CodingKeys: String, CodingKey {
        case index
    }

    required init(name: String, index: Int) {
        self.index = index
        super.init(name: name)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let superDecoder = try container.superDecoder(forKey: .index)
        index = try Int(from: superDecoder)
        let superDecoder2 = try container.superDecoder()
        try super.init(from: superDecoder2)
    }

    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let superEncoder = container.superEncoder(forKey: .index)
        try index.encode(to: superEncoder)
        let superEncoder2 = container.superEncoder()
        try super.encode(to: superEncoder2)
    }
}

extension SuperCodable: Equatable {
    static func == (lhs: SuperCodable, rhs: SuperCodable) -> Bool {
        lhs.name == rhs.name && lhs.index == rhs.index
    }
}

struct Opacity: Equatable {
    private let a: UInt8
    init(a: UInt8) {
        self.a = a
    }
}

extension Opacity: CborCodable {
    var tag: UInt64 { 1 }
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        a = try container.decode(UInt8.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(a)
    }
}
