import Foundation

protocol DataNumber {
    init(data: Data) throws
    var bytes: [UInt8] { get }
}

extension Float16: DataNumber {
    init(data: Data) throws {
        self = .init(bitPattern: .init(bigEndianFixedWidthInt(data, as: UInt16.self)))
    }

    var bytes: [UInt8] {
        withUnsafeBytes(of: bitPattern.bigEndian) {
            Array($0)
        }
    }
}

extension Float: DataNumber {
    init(data: Data) throws {
        self = .init(bitPattern: .init(bigEndianFixedWidthInt(data, as: UInt32.self)))
    }

    var bytes: [UInt8] {
        withUnsafeBytes(of: bitPattern.bigEndian) {
            Array($0)
        }
    }
}

extension Double: DataNumber {
    init(data: Data) throws {
        self = .init(bitPattern: .init(bigEndianFixedWidthInt(data, as: UInt64.self)))
    }

    var bytes: [UInt8] {
        withUnsafeBytes(of: bitPattern.bigEndian) {
            Array($0)
        }
    }
}
