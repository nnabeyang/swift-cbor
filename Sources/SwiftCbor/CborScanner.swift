import Foundation

class CborScanner {
    private let data: Data
    private var off: Int
    init(data: Data) {
        self.data = data
        off = 0
    }

    func read(_ n: Int) throws -> Data {
        defer {
            off += n
        }
        return data[off ..< (off + n)]
    }

    func scan() throws -> CborValue {
        switch try readOpCode() {
        case let .uint(a):
            try scanUInt(additional: a)
        case let .nint(a):
            try scanNInt(additional: a)
        case let .bin(a):
            try scanBinaryString(additional: a)
        case let .str(a):
            try scanString(additional: a)
        case let .tagged(a):
            try scanTaggedValue(additional: a)
        case let .float(a):
            try scanFloat(additional: a)
        case let .array(a):
            try scanArray(additional: a)
        case let .map(a):
            try scanMap(additional: a)
        case .end:
            .none
        }
    }

    private func scanUInt(additional c: UInt8) throws -> CborValue {
        let (data, type) = try _scanUInt(c: c)
        return .literal(.uint(data, type))
    }

    private func scanNInt(additional c: UInt8) throws -> CborValue {
        let (data, type) = try _scanUInt(c: c)
        return .literal(.int(data, type))
    }

    private func scanBinaryString(additional: UInt8) throws -> CborValue {
        try .literal(.bin(scanSequence(additional: additional)))
    }

    private func scanString(additional: UInt8) throws -> CborValue {
        try .literal(.str(scanSequence(additional: additional)))
    }

    private func scanSequence(additional c: UInt8) throws -> Data {
        if let n = try getLength(c: c) {
            return try read(n)
        } else {
            let start = off
            while data[off] != 0xFF {
                off += 1
            }
            return data[start ..< off]
        }
    }

    private func scanFloat(additional c: UInt8) throws -> CborValue {
        switch c {
        case 0x00 ... 0x13:
            .literal(.uint(.init([c]), UInt8.self))
        case 0x14:
            .literal(.bool(false))
        case 0x15:
            .literal(.bool(true))
        case 0x16, 0x17:
            .literal(.nil)
        case 0x18:
            try .literal(.uint(read(1 << 0), UInt8.self))
        case 0x19:
            try .literal(.float16(read(1 << 1)))
        case 0x1A:
            try .literal(.float32(read(1 << 2)))
        case 0x1B:
            try .literal(.float64(read(1 << 3)))
        case 0x1F:
            .literal(.break)
        default:
            .none
        }
    }

    private func scanTaggedValue(additional c: UInt8) throws -> CborValue {
        let (data, type) = try _scanUInt(c: c)
        return try .tagged(tag: .uint(data, type), value: scan())
    }

    private func scanArray(additional c: UInt8) throws -> CborValue {
        var a: [CborValue] = []
        if let n = try getLength(c: c) {
            a.reserveCapacity(n)
            for _ in 0 ..< n {
                try a.append(scan())
            }
        } else {
            while true {
                let e = try scan()
                if case .literal(.break) = e {
                    break
                }
                a.append(e)
            }
        }
        return .array(a)
    }

    private func scanMap(additional c: UInt8) throws -> CborValue {
        var a: [CborValue] = []
        if let n = try getLength(c: c) {
            a.reserveCapacity(n)
            for _ in 0 ..< n {
                try a.append(scan())
                try a.append(scan())
            }
        } else {
            while true {
                let k = try scan()
                if case .literal(.break) = k {
                    break
                }
                let v = try scan()
                if case .literal(.break) = k {
                    break
                }
                a.append(k)
                a.append(v)
            }
        }
        return .map(a)
    }

    private func getLength(c: UInt8) throws -> Int? {
        guard c != 0x1F else { return nil }
        let (data, type) = try _scanUInt(c: c)
        return Int(truncatingIfNeeded: bigEndianFixedWidthInt(data, as: type))
    }

    private func _scanUInt(c: UInt8) throws -> (Data, any FixedWidthInteger.Type) {
        switch c {
        case 0x00 ... 0x17:
            (.init([c]), UInt8.self)
        case 0x18:
            try (read(1 << 0), UInt8.self)
        case 0x19:
            try (read(1 << 1), UInt16.self)
        case 0x1A:
            try (read(1 << 2), UInt32.self)
        case 0x1B:
            try (read(1 << 3), UInt64.self)
        default:
            fatalError()
        }
    }

    private func readOpCode() throws -> CborOpCode {
        if off < data.count {
            defer {
                off += 1
            }
            return CborOpCode(ch: data[off])
        } else {
            return .end
        }
    }
}
