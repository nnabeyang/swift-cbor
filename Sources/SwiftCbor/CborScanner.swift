import Foundation

class CborScanner {
  private let data: Data
  private var off: Int
  let options: CborDecoder.Options
  let allowedTags: Set<UInt64>?

  init(
    data: Data, options: CborDecoder.Options = [], allowedTags: Set<UInt64>? = nil
  ) {
    self.data = data
    off = data.startIndex
    self.options = options
    self.allowedTags = allowedTags
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
    let bytes = try scanSequence(additional: additional)
    if options.contains(.validUTF8Only), String(data: bytes, encoding: .utf8) == nil {
      throw DecodingError.dataCorrupted(
        .init(
          codingPath: [],
          debugDescription: "CBOR text string is not valid UTF-8."
        ))
    }
    return .literal(.str(bytes))
  }

  private func scanSequence(additional c: UInt8) throws -> Data {
    if let n = try getLength(c: c) {
      return read(n)
    } else {
      try rejectIndefiniteLengthItem("byte or text string")
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
      if options.contains(.basicSimpleValuesOnly) { throw unsupportedSimpleValue(c) }
      return .literal(.simple(c))
    case 0x14:
      return .literal(.bool(false))
    case 0x15:
      return .literal(.bool(true))
    case 0x16:
      return .literal(.nil)
    case 0x17:
      if options.contains(.basicSimpleValuesOnly) { throw unsupportedSimpleValue(c) }
      return .literal(.undefined)
    case 0x18:
      let value: UInt8 = bigEndianFixedWidthInt(read(1 << 0), as: UInt8.self)
      if options.contains(.basicSimpleValuesOnly) { throw unsupportedSimpleValue(value) }
      return .literal(.simple(value))
    case 0x19:
      let bytes = read(1 << 1)
      if options.contains(.floatingPoint64Only) { throw requireFloat64Error() }
      if options.contains(.finiteFloatingPointValuesOnly), try !Float16(data: bytes).isFinite {
        throw nonFiniteFloatError()
      }
      return .literal(.float16(bytes))
    case 0x1A:
      let bytes = read(1 << 2)
      if options.contains(.floatingPoint64Only) { throw requireFloat64Error() }
      if options.contains(.finiteFloatingPointValuesOnly), try !Float(data: bytes).isFinite {
        throw nonFiniteFloatError()
      }
      try requireShortestFloatingPointEncoding(bytes, as: Float.self)
      return .literal(.float32(bytes))
    case 0x1B:
      let bytes = read(1 << 3)
      if options.contains(.finiteFloatingPointValuesOnly), try !Double(data: bytes).isFinite {
        throw nonFiniteFloatError()
      }
      try requireShortestFloatingPointEncoding(bytes, as: Double.self)
      return .literal(.float64(bytes))
    case 0x1F:
      if options.contains(.definiteLengthItems) {
        throw DecodingError.dataCorrupted(
          .init(
            codingPath: [],
            debugDescription:
              "A break code is not permitted when definite-length items are required."
          ))
      }
      return .literal(.break)
    default:
      return .none
    }
  }

  private func unsupportedSimpleValue(_ value: UInt8) -> DecodingError {
    DecodingError.dataCorrupted(
      .init(
        codingPath: [],
        debugDescription: "CBOR simple value \(value) is not false, true, or null."
      ))
  }

  private func nonFiniteFloatError() -> DecodingError {
    DecodingError.dataCorrupted(
      .init(
        codingPath: [],
        debugDescription: "Non-finite floating-point values are not permitted."
      ))
  }

  private func requireFloat64Error() -> DecodingError {
    DecodingError.dataCorrupted(
      .init(
        codingPath: [],
        debugDescription: "Floating-point values must use the 64-bit representation."
      ))
  }

  private func scanTaggedValue(additional c: UInt8) throws -> CborValue {
    let tag = try _scanUInt(c: c)
    if let allowedTags, !allowedTags.contains(tag) {
      throw DecodingError.dataCorrupted(
        .init(
          codingPath: [],
          debugDescription: "CBOR tag \(tag) is not in the allowed tag set."
        ))
    }
    return try .tagged(tag: .uint(tag), value: scan())
  }

  private func scanArray(additional c: UInt8) throws -> CborValue {
    var a: [CborValue] = []
    if let n = try getLength(c: c) {
      a.reserveCapacity(n)
      for _ in 0..<n {
        try a.append(scan())
      }
    } else {
      try rejectIndefiniteLengthItem("array")
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
    var previousKeyEncoding: Data?
    if let n = try getLength(c: c) {
      a.reserveCapacity(n)
      for _ in 0..<n {
        let keyStart = off
        let key = try scan()
        try requireLexicographicallySortedMapKey(
          data[keyStart..<off], after: &previousKeyEncoding)
        if options.contains(.stringMapKeysOnly), !key.isTextString {
          throw DecodingError.dataCorrupted(
            .init(
              codingPath: [],
              debugDescription: "CBOR map keys must be text strings."
            ))
        }
        a.append(key)
        try a.append(scan())
      }
    } else {
      try rejectIndefiniteLengthItem("map")
      while true {
        let keyStart = off
        let k = try scan()
        if case .literal(.break) = k {
          break
        }
        try requireLexicographicallySortedMapKey(
          data[keyStart..<off], after: &previousKeyEncoding)
        if options.contains(.stringMapKeysOnly), !k.isTextString {
          throw DecodingError.dataCorrupted(
            .init(
              codingPath: [],
              debugDescription: "CBOR map keys must be text strings."
            ))
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

  private func requireLexicographicallySortedMapKey(
    _ encoding: Data, after previousEncoding: inout Data?
  ) throws {
    guard options.contains(.lexicographicallySortedMapKeys) else { return }
    if let previousEncoding, encoding.lexicographicallyPrecedes(previousEncoding) {
      throw DecodingError.dataCorrupted(
        .init(
          codingPath: [],
          debugDescription: "CBOR map keys are not in bytewise lexicographic order."
        ))
    }
    previousEncoding = encoding
  }

  private func requireShortestFloatingPointEncoding<F: BinaryFloatingPoint & DataNumber>(
    _ bytes: Data, as type: F.Type
  ) throws {
    guard options.contains(.shortestFloatingPointEncoding) else { return }
    let value = try F(data: bytes)

    let canNarrow: Bool
    if value.isNaN {
      canNarrow = canNarrowNaNSignificand(
        UInt64(value.significandBitPattern), from: F.significandBitCount)
    } else {
      let double = Double(value)
      let half = Float16(double)
      if sameFloatingPointValue(Double(half), double) {
        canNarrow = true
      } else if F.self == Double.self {
        let single = Float(double)
        canNarrow = sameFloatingPointValue(Double(single), double)
      } else {
        canNarrow = false
      }
    }

    guard !canNarrow else {
      throw DecodingError.dataCorrupted(
        .init(
          codingPath: [],
          debugDescription: "CBOR floating-point value does not use its shortest encoding."
        ))
    }
  }

  private func canNarrowNaNSignificand(_ significand: UInt64, from sourceWidth: Int) -> Bool {
    canNarrowNaNSignificand(significand, from: sourceWidth, to: 10)
      || (sourceWidth > 23
        && canNarrowNaNSignificand(significand, from: sourceWidth, to: 23))
  }

  private func canNarrowNaNSignificand(
    _ significand: UInt64, from sourceWidth: Int, to targetWidth: Int
  ) -> Bool {
    guard sourceWidth > targetWidth else { return false }
    let discardedWidth = sourceWidth - targetWidth
    let discardedMask = (UInt64(1) << discardedWidth) - 1
    guard significand & discardedMask == 0 else { return false }
    return significand >> discardedWidth != 0
  }

  private func sameFloatingPointValue(_ lhs: Double, _ rhs: Double) -> Bool {
    lhs == rhs && (lhs != 0 || lhs.sign == rhs.sign)
  }

  private func rejectIndefiniteLengthItem(_ kind: String) throws {
    guard options.contains(.definiteLengthItems) else { return }
    throw DecodingError.dataCorrupted(
      .init(
        codingPath: [],
        debugDescription: "Indefinite-length \(kind) is not permitted."
      ))
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
    if off < data.endIndex {
      defer {
        off += 1
      }
      return CborOpCode(ch: data[off])
    } else {
      return .end
    }
  }
}

extension CborValue {
  fileprivate var isTextString: Bool {
    if case .literal(.str) = self { return true }
    return false
  }
}
