@testable import SwiftCbor
import XCTest

final class DecodeTests: XCTestCase {
    private let decoder = CborDecoder()
    func testSimple() throws {
        XCTAssertEqual(try decoder.decode(Bool.self, from: Data(hex: "f4")), false)
        XCTAssertEqual(try decoder.decode(Bool.self, from: Data(hex: "f5")), true)
        XCTAssertEqual(try decoder.decode(String?.self, from: Data(hex: "f6")), String?.none)
    }

    func testFloat() throws {
        XCTAssertEqual(try decoder.decode(Float16.self, from: Data(hex: "f97bff")), Float16.greatestFiniteMagnitude)
        XCTAssertEqual(try decoder.decode(Float.self, from: Data(hex: "fa7f7fffff")), Float.greatestFiniteMagnitude)
        XCTAssertEqual(try decoder.decode(Double.self, from: Data(hex: "fb7fefffffffffffff")), Double.greatestFiniteMagnitude)
        XCTAssertEqual(try decoder.decode(Float16.self, from: Data(hex: "f97c00")), Float16.infinity)
        XCTAssertEqual(try decoder.decode(Float.self, from: Data(hex: "fa7f800000")), Float.infinity)
        XCTAssertEqual(try decoder.decode(Double.self, from: Data(hex: "fb7ff0000000000000")), Double.infinity)
        XCTAssertEqual(try decoder.decode(Float16.self, from: Data(hex: "f97e00")).debugDescription, "nan")
        XCTAssertEqual(try decoder.decode(Float.self, from: Data(hex: "fa7fc00000")).debugDescription, "nan")
        XCTAssertEqual(try decoder.decode(Double.self, from: Data(hex: "fb7ff8000000000000")).debugDescription, "nan")
    }

    func testStruct() throws {
        let data = Data(hex: "b764626f6f6cf563696e743b0000004b6b34abcb64696e7438383465696e743136394b6a65696e7433323a004b6b3365696e7436343b0000004b6b34abcb6475696e741b0000004b6b34abcc6575696e743818356675696e743136194b6b6675696e7433321a004b6b346675696e7436341b0000004b6b34abcc67666c6f61743136f9424865666c6f6174fa47ffe00066646f75626c65fb47ffffffe000000066737472696e676548656c6c6f67737472696e674d6fe38193e38293e381abe381a1e381af636d6170a2623138a163746167657461673138623137a163746167657461673137646d617050a2623139a163746167657461673139623230f668666c6f61744d6170a2fa3fb47ae16773717274283229fa4048f5c36270696a656d707479417272617980656279746573431b1c1d6c7375706572436f6461626c65a265696e64657803657375706572a1646e616d656568656c6c6f66746167676564c11846")
        XCTAssertEqual(try decoder.decode(All.self, from: data), All.value)
    }

    func testMap() {
        XCTAssertEqual(try decoder.decode([String: String].self, from: Data(hex: "a0")), [String: String]())
        XCTAssertEqual(try decoder.decode([String: UInt64].self, from: Data(hex: "a56374776f18ff64666976651bffffffffffffffff65746872656519ffff64666f75721affffffff636f6e6517")), [
            "one": UInt64(0x17),
            "two": UInt64(UInt8.max),
            "three": UInt64(UInt16.max),
            "four": UInt64(UInt32.max),
            "five": UInt64.max,
        ])
    }

    func testArray() {
        XCTAssertEqual(try decoder.decode([Int].self, from: Data(hex: "80")), [Int]())
        XCTAssertEqual(try decoder.decode([Int].self, from: Data(hex: "83010203")), [1, 2, 3])
        XCTAssertEqual(try decoder.decode([Int].self, from: Data(hex: "98190102030405060708090a0b0c0d0e0f101112131415161718181819")), [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25])
        XCTAssertEqual(try decoder.decode([[Int]].self, from: Data(hex: "838101820203820405")), [[1], [2, 3], [4, 5]])
        XCTAssertEqual(try decoder.decode([Int].self, from: Data(hex: "9F010203FF")), [1, 2, 3])
        XCTAssertEqual(try decoder.decode([[Int]].self, from: Data(hex: "9F81018202039F0405FFFF")), [[1], [2, 3], [4, 5]])
    }

    func testString() throws {
        XCTAssertEqual(try decoder.decode(String.self, from: Data(hex: "60")), "")
        XCTAssertEqual(try decoder.decode(String.self, from: Data(hex: "6161")), "a")
        XCTAssertEqual(try decoder.decode(String.self, from: Data(hex: "6b48656c6c6f20576f726c64")), "Hello World")
        XCTAssertEqual(try decoder.decode(String.self, from: Data(hex: "7818e38193e38293e381abe381a1e381afe38081e4b896e7958c")), "こんにちは、世界")
        XCTAssertEqual(try decoder.decode(String.self, from: Data(hex: "7fe38193e38293e381abe381a1e381afe38081e4b896e7958cff")), "こんにちは、世界")
    }

    func testByteString() throws {
        XCTAssertEqual(try decoder.decode(Data.self, from: Data(hex: "4401020304")), Data(hex: "01020304"))
        XCTAssertEqual(try decoder.decode(Data.self, from: Data(hex: "581a6162636465666768696a6b6c6d6e6f707172737475767778797a")), Data("abcdefghijklmnopqrstuvwxyz".utf8))
        XCTAssertEqual(try decoder.decode(Data.self, from: Data(hex: "5f6162636465666768696a6b6c6d6e6f707172737475767778797aff")), Data("abcdefghijklmnopqrstuvwxyz".utf8))
        XCTAssertEqual(try decoder.decode(Data.self, from: Data(hex: "7818e38193e38293e381abe381a1e381afe38081e4b896e7958c")), Data("こんにちは、世界".utf8))
    }

    func testInt() throws {
        // positive
        XCTAssertEqual(try decoder.decode(Int8.self, from: Data(hex: "17")), Int8(0x17))
        XCTAssertEqual(try decoder.decode(Int8.self, from: Data(hex: "1818")), Int8(0x18))
        XCTAssertEqual(try decoder.decode(Int8.self, from: Data(hex: "187f")), Int8.max)
        XCTAssertEqual(try decoder.decode(Int16.self, from: Data(hex: "197fff")), Int16.max)
        XCTAssertEqual(try decoder.decode(Int32.self, from: Data(hex: "1a7fffffff")), Int32.max)
        XCTAssertEqual(try decoder.decode(Int64.self, from: Data(hex: "1b7fffffffffffffff")), Int64.max)
        // negative
        XCTAssertEqual(try decoder.decode(Int8.self, from: Data(hex: "20")), Int8(~0))
        XCTAssertEqual(try decoder.decode(Int8.self, from: Data(hex: "25")), Int8(~0x5))
        XCTAssertEqual(try decoder.decode(Int8.self, from: Data(hex: "37")), Int8(~0x17))
        XCTAssertEqual(try decoder.decode(Int8.self, from: Data(hex: "3818")), Int8(~0x17) - 1)
        XCTAssertEqual(try decoder.decode(Int16.self, from: Data(hex: "38ff")), ~Int16(UInt8.max))
        XCTAssertEqual(try decoder.decode(Int16.self, from: Data(hex: "390100")), ~Int16(UInt8.max) - 1)
        XCTAssertEqual(try decoder.decode(Int32.self, from: Data(hex: "39ffff")), ~Int32(UInt16.max))
        XCTAssertEqual(try decoder.decode(Int32.self, from: Data(hex: "3a00010000")), ~Int32(UInt16.max) - 1)
        XCTAssertEqual(try decoder.decode(Int64.self, from: Data(hex: "3affffffff")), ~Int64(UInt32.max))
        XCTAssertEqual(try decoder.decode(Int64.self, from: Data(hex: "3b0000000100000000")), ~Int64(UInt32.max) - 1)
        XCTAssertEqual(try decoder.decode(Int64.self, from: Data(hex: "3b7fffffffffffffff")), Int64.min)
    }

    func testDecodeUInt() throws {
        XCTAssertEqual(try decoder.decode(UInt8.self, from: Data(hex: "00")), UInt8.min)
        XCTAssertEqual(try decoder.decode(UInt8.self, from: Data(hex: "17")), UInt8(0x17))
        XCTAssertEqual(try decoder.decode(UInt8.self, from: Data(hex: "1818")), UInt8(0x18))
        XCTAssertEqual(try decoder.decode(UInt8.self, from: Data(hex: "18ff")), UInt8.max)
        XCTAssertEqual(try decoder.decode(UInt16.self, from: Data(hex: "190100")), UInt16(UInt8.max) + 1)
        XCTAssertEqual(try decoder.decode(UInt16.self, from: Data(hex: "19ffff")), UInt16.max)
        XCTAssertEqual(try decoder.decode(UInt32.self, from: Data(hex: "1a00010000")), UInt32(UInt16.max) + 1)
        XCTAssertEqual(try decoder.decode(UInt32.self, from: Data(hex: "1affffffff")), UInt32.max)
        XCTAssertEqual(try decoder.decode(UInt64.self, from: Data(hex: "1b0000000100000000")), UInt64(UInt32.max) + 1)
        XCTAssertEqual(try decoder.decode(UInt64.self, from: Data(hex: "1bffffffffffffffff")), UInt64.max)
    }
}

private extension UnicodeScalar {
    var hexNibble: UInt8 {
        let value = value
        if value >= 48, value <= 57 {
            return UInt8(value - 48)
        } else if value >= 65, value <= 70 {
            return UInt8(value - 55)
        } else if value >= 97, value <= 102 {
            return UInt8(value - 87)
        }
        fatalError("\(self) not a legal hex nibble")
    }
}

extension Data {
    init(hex: String) {
        let scalars = hex.unicodeScalars
        var bytes = [UInt8](repeating: 0, count: (scalars.count + 1) >> 1)
        for (index, scalar) in scalars.enumerated() {
            var nibble = scalar.hexNibble
            if index & 1 == 0 {
                nibble <<= 4
            }
            bytes[index >> 1] |= nibble
        }
        self = Data(bytes)
    }
}

extension Data {
    var hexDescription: String {
        reduce("") { $0 + String(format: "%02x", $1) }
    }
}
