import Foundation

class CborScanner {
  private let data: Data
  private var off: Int
  let options: CborDecoder.Options

  init(data: Data, options: CborDecoder.Options = []) {
    self.data = data
    off = 0
    self.options = options
  }

  private func read(_ n: Int) -> Data {
    defer {
      off += n
    }
    return data[off..<(off + n)]
  }

  func scan() throws -> CborValue {
    switch readOpCode() {
    case .uint(let a):
      try scanUInt(additional: a)
    case .nint(let a):
      try scanNInt(additional: a)
    case .bin(let a):
      try scanBinaryString(additional: a)
    case .str(let a):
      try scanString(additional: a)
    case .tagged(let a):
      try scanTaggedValue(additional: a)
    case .float(let a):
      try scanFloat(additional: a)
    case .array(let a):
      try scanArray(additional: a)
    case .map(let a):
      try scanMap(additional: a)
    case .end:
      .none
    }
  }

  private func scanUInt(additional c: UInt8) throws -> CborValue {
    .literal(.uint(try _scanUInt(c: c)))
  }

  private func scanNInt(additional c: UInt8) throws -> CborValue {
    .literal(.int(try _scanUInt(c: c)))
  }

  private func scanBinaryString(additional: UInt8) throws -> CborValue {
    try .literal(.bin(scanSequence(additional: additional)))
  }

  private func scanString(additional: UInt8) throws -> CborValue {
    try .literal(.str(scanSequence(additional: additional)))
  }

  private func scanSequence(additional c: UInt8) throws -> Data {
    if let n = try getLength(c: c) {
      return read(n)
    } else {
      let start = off
      while data[off] != 0xFF {
        off += 1
      }
      return data[start..<off]
    }
  }

  private func scanFloat(additional c: UInt8) throws -> CborValue {
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

  private func scanTaggedValue(additional c: UInt8) throws -> CborValue {
    return try .tagged(tag: .uint(_scanUInt(c: c)), value: scan())
  }

  private func scanArray(additional c: UInt8) throws -> CborValue {
    var a: [CborValue] = []
    if let n = try getLength(c: c) {
      a.reserveCapacity(n)
      for _ in 0..<n {
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
      for _ in 0..<n {
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
    return Int(truncatingIfNeeded: try _scanUInt(c: c))
  }

  private func _scanUInt(c: UInt8) throws -> UInt64 {
    if case 0x00...0x17 = c {
      return UInt64(c)
    }

    let result: UInt64
    switch c {
    case 0x18:
      result = UInt64(bigEndianFixedWidthInt(read(1 << 0), as: UInt8.self))
    case 0x19:
      result = UInt64(bigEndianFixedWidthInt(read(1 << 1), as: UInt16.self))
    case 0x1A:
      result = UInt64(bigEndianFixedWidthInt(read(1 << 2), as: UInt32.self))
    case 0x1B:
      result = bigEndianFixedWidthInt(read(1 << 3), as: UInt64.self)
    default:
      fatalError()
    }
    if options.contains(.minimalArgumentEncoding) {
      try requireMinimalArgument(additional: c, value: result)
    }
    return result
  }

  private func requireMinimalArgument(additional c: UInt8, value: UInt64) throws {
    let minimum: UInt64
    switch c {
    case 0x18:
      minimum = UInt64(Int.fixMax) + 1
    case 0x19:
      minimum = UInt64(UInt8.max) + 1
    case 0x1A:
      minimum = UInt64(UInt16.max) + 1
    case 0x1B:
      minimum = UInt64(UInt32.max) + 1
    default:
      return
    }
    guard value >= minimum else {
      throw DecodingError.dataCorrupted(
        .init(
          codingPath: [],
          debugDescription: "CBOR argument uses a non-minimal encoding."
        ))
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
