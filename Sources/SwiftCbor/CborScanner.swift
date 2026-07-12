import Foundation

class CborScanner {
  private let data: Data
  private var off: Int
  init(data: Data) {
    self.data = data
    off = 0
  }

  private func read(_ n: Int) -> Data {
    defer {
      off += n
    }
    return data[off..<(off + n)]
  }

  func scan() -> CborValue {
    switch readOpCode() {
    case .uint(let a):
      scanUInt(additional: a)
    case .nint(let a):
      scanNInt(additional: a)
    case .bin(let a):
      scanBinaryString(additional: a)
    case .str(let a):
      scanString(additional: a)
    case .tagged(let a):
      scanTaggedValue(additional: a)
    case .float(let a):
      scanFloat(additional: a)
    case .array(let a):
      scanArray(additional: a)
    case .map(let a):
      scanMap(additional: a)
    case .end:
      .none
    }
  }

  private func scanUInt(additional c: UInt8) -> CborValue {
    .literal(.uint(_scanUInt(c: c)))
  }

  private func scanNInt(additional c: UInt8) -> CborValue {
    .literal(.int(_scanUInt(c: c)))
  }

  private func scanBinaryString(additional: UInt8) -> CborValue {
    .literal(.bin(scanSequence(additional: additional)))
  }

  private func scanString(additional: UInt8) -> CborValue {
    .literal(.str(scanSequence(additional: additional)))
  }

  private func scanSequence(additional c: UInt8) -> Data {
    if let n = getLength(c: c) {
      return read(n)
    } else {
      let start = off
      while data[off] != 0xFF {
        off += 1
      }
      return data[start..<off]
    }
  }

  private func scanFloat(additional c: UInt8) -> CborValue {
    switch c {
    case 0x00...0x13:
      .literal(.uint(UInt64(c)))
    case 0x14:
      .literal(.bool(false))
    case 0x15:
      .literal(.bool(true))
    case 0x16, 0x17:
      .literal(.nil)
    case 0x18:
      .literal(.uint(UInt64(bigEndianFixedWidthInt(read(1 << 0), as: UInt8.self))))
    case 0x19:
      .literal(.float16(read(1 << 1)))
    case 0x1A:
      .literal(.float32(read(1 << 2)))
    case 0x1B:
      .literal(.float64(read(1 << 3)))
    case 0x1F:
      .literal(.break)
    default:
      .none
    }
  }

  private func scanTaggedValue(additional c: UInt8) -> CborValue {
    .tagged(tag: .uint(_scanUInt(c: c)), value: scan())
  }

  private func scanArray(additional c: UInt8) -> CborValue {
    var a: [CborValue] = []
    if let n = getLength(c: c) {
      a.reserveCapacity(n)
      for _ in 0..<n {
        a.append(scan())
      }
    } else {
      while true {
        let e = scan()
        if case .literal(.break) = e {
          break
        }
        a.append(e)
      }
    }
    return .array(a)
  }

  private func scanMap(additional c: UInt8) -> CborValue {
    var a: [CborValue] = []
    if let n = getLength(c: c) {
      a.reserveCapacity(n)
      for _ in 0..<n {
        a.append(scan())
        a.append(scan())
      }
    } else {
      while true {
        let k = scan()
        if case .literal(.break) = k {
          break
        }
        let v = scan()
        if case .literal(.break) = k {
          break
        }
        a.append(k)
        a.append(v)
      }
    }
    return .map(a)
  }

  private func getLength(c: UInt8) -> Int? {
    guard c != 0x1F else { return nil }
    return Int(truncatingIfNeeded: _scanUInt(c: c))
  }

  private func _scanUInt(c: UInt8) -> UInt64 {
    switch c {
    case 0x00...0x17:
      UInt64(c)
    case 0x18:
      UInt64(bigEndianFixedWidthInt(read(1 << 0), as: UInt8.self))
    case 0x19:
      UInt64(bigEndianFixedWidthInt(read(1 << 1), as: UInt16.self))
    case 0x1A:
      UInt64(bigEndianFixedWidthInt(read(1 << 2), as: UInt32.self))
    case 0x1B:
      bigEndianFixedWidthInt(read(1 << 3), as: UInt64.self)
    default:
      fatalError()
    }
  }

  private func readOpCode() -> CborOpCode {
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
