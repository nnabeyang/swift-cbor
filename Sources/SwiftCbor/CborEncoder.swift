import Foundation

private protocol _CborDictionaryEncodableMarker {}

extension Dictionary: _CborDictionaryEncodableMarker where Key: Encodable, Value: Encodable {}

open class CborEncoder {
  public var options: Options

  public init(options: Options = []) {
    self.options = options
  }

  open func encode(_ value: some Encodable) throws -> Data {
    let value: CborEncodedValue = try encodeAsCborValue(value)
    let writer = CborValue.Writer(
      sortMapKeysLexicographically: options.contains(.lexicographicallySortedMapKeys)
    )
    let bytes = writer.writeValue(value)
    return Data(bytes)
  }

  func encodeAsCborValue<T: Encodable>(_ value: T) throws -> CborEncodedValue {
    let encoder = _CborEncoder(codingPath: [], options: options)
    guard let result = try encoder.wrapEncodable(value, for: CodingKey?.none) else {
      throw EncodingError.invalidValue(
        value,
        EncodingError.Context(
          codingPath: [], debugDescription: "Top-level \(T.self) did not encode any values."))
    }
    return result
  }
}

private class _CborEncoder: Encoder {
  public var codingPath: [CodingKey] = []
  public var userInfo: [CodingUserInfoKey: Any] = [:]
  let options: CborEncoder.Options

  init(codingPath: [CodingKey], options: CborEncoder.Options) {
    self.codingPath = codingPath
    self.options = options
  }

  var singleValue: CborEncodedValue?
  var array: CborFuture.RefArray?
  var map: CborFuture.RefMap?
  var value: CborEncodedValue? {
    if let array: CborFuture.RefArray = array {
      return .array(array.values)
    }
    if let map: CborFuture.RefMap = map {
      var a: [CborEncodedValue] = []
      let values = map.values
      a.reserveCapacity(values.count * 2)
      for (k, v) in values {
        a.append(k)
        a.append(v)
      }
      return .map(a)
    }
    return singleValue
  }

  public func container<Key>(keyedBy _: Key.Type) -> KeyedEncodingContainer<Key>
  where Key: CodingKey {
    if map != nil {
      return KeyedEncodingContainer(
        CborKeyedEncodingContainer(referencing: self, codingPath: codingPath))
    }
    map = .init()
    return KeyedEncodingContainer(
      CborKeyedEncodingContainer(referencing: self, codingPath: codingPath))
  }

  public func unkeyedContainer() -> UnkeyedEncodingContainer {
    if array != nil {
      return CborUnkeyedEncodingContainer(referencing: self, codingPath: codingPath)
    }
    array = .init()
    return CborUnkeyedEncodingContainer(referencing: self, codingPath: codingPath)
  }

  public func singleValueContainer() -> SingleValueEncodingContainer {
    CborSingleValueEncodingContainer(encoder: self, codingPath: codingPath)
  }
}

extension _CborEncoder: _SpecialTreatmentEncoder {
  var encoder: _CborEncoder {
    self
  }
}

private enum CborFuture {
  case value(CborEncodedValue)
  case encoder(_CborEncoder)
  case nestedArray(RefArray)
  case nestedMap(RefMap)

  class RefArray {
    private(set) var array: [CborFuture] = []

    init() {
      array.reserveCapacity(10)
    }

    @inline(__always)
    func append(_ element: CborEncodedValue) {
      array.append(.value(element))
    }

    @inline(__always)
    func append(_ encoder: _CborEncoder) {
      array.append(.encoder(encoder))
    }

    @inline(__always)
    func appendArray() -> RefArray {
      let array = RefArray()
      self.array.append(.nestedArray(array))
      return array
    }

    @inline(__always)
    func appendMap() -> RefMap {
      let map = RefMap()
      array.append(.nestedMap(map))
      return map
    }

    var values: [CborEncodedValue] {
      array.compactMap { future in
        switch future {
        case .value(let value):
          return value
        case .nestedArray(let array):
          return .array(array.values)
        case .nestedMap(let map):
          let values = map.values
          let n = values.count
          var a: [CborEncodedValue] = []
          a.reserveCapacity(n * 2)
          for (k, v) in values {
            a.append(k)
            a.append(v)
          }
          return .map(a)
        case .encoder(let encoder):
          return encoder.value
        }
      }
    }
  }

  class RefMap {
    private(set) var keys: [CborStringKey] = []
    private(set) var dict: [String: CborFuture] = [:]
    init() {
      dict.reserveCapacity(20)
    }

    @inline(__always)
    func set(_ value: CborEncodedValue, for key: CborStringKey) {
      if dict[key.stringValue] == nil {
        keys.append(key)
      }
      dict[key.stringValue] = .value(value)
    }

    @inline(__always)
    func setArray(for key: CborStringKey) -> RefArray {
      switch dict[key.stringValue] {
      case .nestedArray(let array):
        return array
      case .value:
        let array: CborFuture.RefArray = .init()
        dict[key.stringValue] = .nestedArray(array)
        return array
      case .none:
        let array: CborFuture.RefArray = .init()
        dict[key.stringValue] = .nestedArray(array)
        keys.append(key)
        return array
      case .nestedMap:
        preconditionFailure("For key \"\(key)\" a keyed container has already been created.")
      case .encoder:
        preconditionFailure("For key \"\(key)\" an encoder has already been created.")
      }
    }

    @inline(__always)
    func setMap(for key: CborStringKey) -> RefMap {
      switch dict[key.stringValue] {
      case .nestedMap(let map):
        return map
      case .value:
        let map: CborFuture.RefMap = .init()
        dict[key.stringValue] = .nestedMap(map)
        return map
      case .none:
        let map: CborFuture.RefMap = .init()
        dict[key.stringValue] = .nestedMap(map)
        keys.append(key)
        return map
      case .nestedArray:
        preconditionFailure("For key \"\(key)\" a unkeyed container has already been created.")
      case .encoder:
        preconditionFailure("For key \"\(key)\" an encoder has already been created.")
      }
    }

    @inline(__always)
    func set(_ encoder: _CborEncoder, for key: CborStringKey) {
      switch dict[key.stringValue] {
      case .encoder:
        preconditionFailure("For key \"\(key)\" an encoder has already been created.")
      case .nestedMap:
        preconditionFailure("For key \"\(key)\" a keyed container has already been created.")
      case .nestedArray:
        preconditionFailure("For key \"\(key)\" a unkeyed container has already been created.")
      case .value:
        dict[key.stringValue] = .encoder(encoder)
      case .none:
        dict[key.stringValue] = .encoder(encoder)
        keys.append(key)
      }
    }

    var values: [(CborEncodedValue, CborEncodedValue)] {
      keys.compactMap {
        switch dict[$0.stringValue] {
        case .value(let value):
          return ($0.CborValue, value)
        case .nestedArray(let array):
          return ($0.CborValue, .array(array.values))
        case .nestedMap(let map):
          var a: [CborEncodedValue] = []
          let values = map.values
          a.reserveCapacity(values.count * 2)
          for (k, v) in map.values {
            a.append(k)
            a.append(v)
          }
          return ($0.CborValue, .map(a))
        case .encoder(let encoder):
          guard let value = encoder.value else {
            return nil
          }
          return ($0.CborValue, value)
        case .none:
          return nil
        }
      }
    }
  }
}

private protocol _SpecialTreatmentEncoder {
  var codingPath: [CodingKey] { get }
  var encoder: _CborEncoder { get }
}

extension FixedWidthInteger {
  func bigEndianBytes<T: FixedWidthInteger>(as _: T.Type) -> [UInt8] {
    withUnsafeBytes(of: T(self).bigEndian) { Array($0) }
  }
}

extension _SpecialTreatmentEncoder {
  fileprivate func wrapFloat<F: BinaryFloatingPoint & DataNumber>(
    _ value: F, for additionalKey: CodingKey?
  ) throws -> CborEncodedValue {
    if encoder.options.contains(.shortestFloatingPointEncoding) {
      return shortestFloatingPointValue(value)
    }
    let bits = value.bytes
    if bits.count == 2 {
      return .literal([0xF9] + bits)
    }
    if bits.count == 4 {
      return .literal([0xFA] + bits)
    }
    if bits.count == 8 {
      return .literal([0xFB] + bits)
    }
    let path: [CodingKey] =
      if let additionalKey {
        codingPath + [additionalKey]
      } else {
        codingPath
      }
    throw EncodingError.invalidValue(
      value,
      .init(
        codingPath: path,
        debugDescription: "Unable to encode \(F.self).\(value) directly in MessagePack."
      ))
  }

  private func shortestFloatingPointValue(
    _ value: some BinaryFloatingPoint & DataNumber
  ) -> CborEncodedValue {
    if value.isNaN {
      return shortestNaNValue(value)
    }

    let double = Double(value)
    let half = Float16(double)
    if sameFloatingPointValue(Double(half), double) {
      return .literal([0xF9] + half.bytes)
    }

    let single = Float(double)
    if sameFloatingPointValue(Double(single), double) {
      return .literal([0xFA] + single.bytes)
    }

    return .literal([0xFB] + double.bytes)
  }

  private func shortestNaNValue<F: BinaryFloatingPoint & DataNumber>(
    _ value: F
  ) -> CborEncodedValue {
    let significand = UInt64(value.significandBitPattern)
    let sourceWidth = F.significandBitCount
    let isNegative = value.sign == .minus

    if let narrowed = narrowedNaNSignificand(significand, from: sourceWidth, to: 10) {
      let sign: UInt16 = isNegative ? 0x8000 : 0
      let bits = Float16(bitPattern: sign | 0x7C00 | UInt16(narrowed)).bytes
      return .literal([0xF9] + bits)
    }

    if let narrowed = narrowedNaNSignificand(significand, from: sourceWidth, to: 23) {
      let sign: UInt32 = isNegative ? 0x8000_0000 : 0
      let bits = Float(bitPattern: sign | 0x7F80_0000 | UInt32(narrowed)).bytes
      return .literal([0xFA] + bits)
    }

    return .literal([0xFB] + value.bytes)
  }

  private func narrowedNaNSignificand(
    _ significand: UInt64, from sourceWidth: Int, to targetWidth: Int
  ) -> UInt64? {
    guard sourceWidth >= targetWidth else { return nil }
    let discardedWidth = sourceWidth - targetWidth
    let discardedMask = discardedWidth == 0 ? 0 : (UInt64(1) << discardedWidth) - 1
    guard significand & discardedMask == 0 else { return nil }
    let narrowed = significand >> discardedWidth
    return narrowed == 0 ? nil : narrowed
  }

  private func sameFloatingPointValue(_ lhs: Double, _ rhs: Double) -> Bool {
    lhs == rhs && (lhs != 0 || lhs.sign == rhs.sign)
  }

  fileprivate func wrapInt(
    _ value: some SignedInteger & FixedWidthInteger, for additionalKey: CodingKey?
  ) throws -> CborEncodedValue {
    if value >= 0 {
      try wrapUInt(UInt64(value), majorType: 0b0000_0000, for: additionalKey)
    } else {
      try wrapUInt(~UInt64(bitPattern: Int64(value)), majorType: 0b0010_0000, for: additionalKey)
    }
  }

  fileprivate func wrapUInt<T: UnsignedInteger & FixedWidthInteger>(
    _ value: T, majorType: UInt8 = 0, for additionalKey: CodingKey?
  ) throws -> CborEncodedValue {
    if value <= Int.fixMax {
      return .literal([majorType | UInt8(value)])
    }
    if value <= UInt8.max {
      return .literal([majorType | 0x18, UInt8(value)])
    }
    if value <= UInt16.max {
      return .literal([majorType | 0x19] + value.bigEndianBytes(as: UInt16.self))
    }
    if value <= UInt32.max {
      return .literal([majorType | 0x1A] + value.bigEndianBytes(as: UInt32.self))
    }
    if value <= UInt64.max {
      return .literal([majorType | 0x1B] + value.bigEndianBytes(as: UInt64.self))
    }

    let path: [CodingKey] =
      if let additionalKey {
        codingPath + [additionalKey]
      } else {
        codingPath
      }
    throw EncodingError.invalidValue(
      value,
      .init(
        codingPath: path,
        debugDescription: "Unable to encode \(T.self).\(value) directly in MessagePack."
      ))
  }

  fileprivate func wrapBool(_ value: Bool) -> CborEncodedValue {
    .literal(value ? [0xF5] : [0xF4])
  }

  fileprivate func wrapStringKey(_ value: String, for key: CodingKey?) throws -> CborStringKey {
    try CborStringKey(stringValue: value, CborValue: wrapString(value, for: key))
  }

  fileprivate func wrapString(_ value: String, for _: CodingKey?) throws -> CborEncodedValue {
    let data = Data(value.utf8)
    let majorType: UInt8 = 0b0110_0000
    let n = data.count
    if n <= Int.fixMax {
      let bits = [UInt8(n) | majorType] + [UInt8](data)
      return .literal(bits)
    } else if n <= UInt8.max {
      let bits = [majorType | 0x18, UInt8(n)] + [UInt8](data)
      return .literal(bits)
    } else if n <= UInt16.max {
      let bits = [majorType | 0x19] + n.bigEndianBytes(as: UInt16.self) + [UInt8](data)
      return .literal(bits)
    } else if n <= UInt32.max {
      let bits = [majorType | 0x1A] + n.bigEndianBytes(as: UInt32.self) + [UInt8](data)
      return .literal(bits)
    } else if n <= Int.max {
      let bits = [majorType | 0x1B] + n.bigEndianBytes(as: UInt64.self) + [UInt8](data)
      return .literal(bits)
    }
  }

  fileprivate func wrapEncodable(_ encodable: some Encodable, for additionalKey: CodingKey?) throws
    -> CborEncodedValue?
  {
    let encoder = getEncoder(for: additionalKey)
    switch encodable {
    case let data as Data:
      return try wrapData(data, for: additionalKey)
    case let cborEncodable as CborEncodable:
      return try wrapCborEncodable(cborEncodable, for: additionalKey)
    case let float16 as Float16:
      return try wrapFloat(float16, for: additionalKey)
    default:
      try encodable.encode(to: encoder)
    }

    if (encodable as? _CborDictionaryEncodableMarker) != nil {
      return encoder.value?.asMap()
    }

    return encoder.value
  }

  fileprivate func wrapData(_ data: Data, for _: CodingKey?) throws -> CborEncodedValue {
    let majorType: UInt8 = 0b0100_0000
    let n = data.count
    if n <= Int.fixMax {
      let bits = [UInt8(n) | majorType] + [UInt8](data)
      return .literal(bits)
    } else if n <= UInt8.max {
      let bits = [majorType | 0x18, UInt8(n)] + [UInt8](data)
      return .literal(bits)
    } else if n <= UInt16.max {
      let bits = [majorType | 0x19] + n.bigEndianBytes(as: UInt16.self) + [UInt8](data)
      return .literal(bits)
    } else if n <= UInt32.max {
      let bits = [majorType | 0x1A] + n.bigEndianBytes(as: UInt32.self) + [UInt8](data)
      return .literal(bits)
    } else if n <= Int.max {
      let bits = [majorType | 0x1B] + n.bigEndianBytes(as: UInt64.self) + [UInt8](data)
      return .literal(bits)
    }
  }

  fileprivate func wrapCborEncodable(_ encodable: CborEncodable, for additionalKey: CodingKey?)
    throws -> CborEncodedValue?
  {
    let tag = try encoder.wrapUInt(encodable.tag, majorType: 0b1100_0000, for: additionalKey)
    let encoder = getEncoder(for: additionalKey)
    try encodable.encode(to: encoder)
    guard let value = encoder.value else { return nil }
    return .tagged(tag: tag, value: value)
  }

  fileprivate func getEncoder(for additionalKey: CodingKey?) -> _CborEncoder {
    if let additionalKey {
      let newCodidngPath: [CodingKey] = codingPath + [additionalKey]
      return _CborEncoder(codingPath: newCodidngPath, options: encoder.options)
    }
    return encoder
  }
}

private struct CborSingleValueEncodingContainer: SingleValueEncodingContainer,
  _SpecialTreatmentEncoder
{
  let encoder: _CborEncoder
  let codingPath: [CodingKey]

  init(encoder: _CborEncoder, codingPath: [CodingKey]) {
    self.encoder = encoder
    self.codingPath = codingPath
  }

  public func encodeNil() throws {
    encoder.singleValue = .Nil
  }

  public func encode(_ value: Bool) throws {
    encoder.singleValue = encoder.wrapBool(value)
  }

  public func encode(_ value: String) throws {
    encoder.singleValue = try encoder.wrapString(value, for: nil)
  }

  public func encode(_ value: Double) throws {
    try encodeFloat(value)
  }

  public func encode(_ value: Float) throws {
    try encodeFloat(value)
  }

  public func encode(_ value: Int) throws {
    try encodeInt(value)
  }

  public func encode(_ value: Int8) throws {
    try encodeInt(value)
  }

  public func encode(_ value: Int16) throws {
    try encodeInt(value)
  }

  public func encode(_ value: Int32) throws {
    try encodeInt(value)
  }

  public func encode(_ value: Int64) throws {
    try encodeInt(value)
  }

  public func encode(_ value: UInt) throws {
    encoder.singleValue = try encoder.wrapUInt(value, for: nil)
  }

  public func encode(_ value: UInt8) throws {
    encoder.singleValue = try encoder.wrapUInt(value, for: nil)
  }

  public func encode(_ value: UInt16) throws {
    encoder.singleValue = try encoder.wrapUInt(value, for: nil)
  }

  public func encode(_ value: UInt32) throws {
    encoder.singleValue = try encoder.wrapUInt(value, for: nil)
  }

  public func encode(_ value: UInt64) throws {
    encoder.singleValue = try encoder.wrapUInt(value, for: nil)
  }

  public func encode(_ value: some Encodable) throws {
    encoder.singleValue = try wrapEncodable(value, for: nil)
  }

  @inline(__always)
  private func encodeInt<T: SignedInteger & FixedWidthInteger>(_ value: T) throws {
    encoder.singleValue = try encoder.wrapInt(value, for: nil)
  }

  @inline(__always)
  private func encodeFloat<T: BinaryFloatingPoint & DataNumber>(_ value: T) throws {
    encoder.singleValue = try encoder.wrapFloat(value, for: nil)
  }
}

private struct CborUnkeyedEncodingContainer: UnkeyedEncodingContainer {
  private let encoder: _CborEncoder
  let array: CborFuture.RefArray
  private(set) var codingPath: [CodingKey]
  var count: Int {
    array.array.count
  }

  init(referencing encoder: _CborEncoder, codingPath: [CodingKey]) {
    self.encoder = encoder
    array = encoder.array!
    self.codingPath = codingPath
  }

  init(referencing encoder: _CborEncoder, array: CborFuture.RefArray, codingPath: [CodingKey]) {
    self.encoder = encoder
    self.array = array
    self.codingPath = codingPath
  }

  func encodeNil() throws {
    array.append(.Nil)
  }

  func encode(_ value: Bool) throws {
    array.append(encoder.wrapBool(value))
  }

  func encode(_ value: String) throws {
    try array.append(encoder.wrapString(value, for: nil))
  }

  func encode(_ value: Double) throws {
    try encodeFloat(value)
  }

  func encode(_ value: Float) throws {
    try encodeFloat(value)
  }

  func encode(_ value: Int) throws {
    try encodeInt(value)
  }

  func encode(_ value: Int8) throws {
    try encodeInt(value)
  }

  func encode(_ value: Int16) throws {
    try encodeInt(value)
  }

  func encode(_ value: Int32) throws {
    try encodeInt(value)
  }

  func encode(_ value: Int64) throws {
    try encodeInt(value)
  }

  func encode(_ value: UInt) throws {
    try encodeUInt(value)
  }

  func encode(_ value: UInt8) throws {
    try encodeUInt(value)
  }

  func encode(_ value: UInt16) throws {
    try encodeUInt(value)
  }

  func encode(_ value: UInt32) throws {
    try encodeUInt(value)
  }

  func encode(_ value: UInt64) throws {
    try encodeUInt(value)
  }

  func encode(_ value: some Encodable) throws {
    let key: CborKey = .init(index: count)
    let encoded = try encoder.wrapEncodable(value, for: key)
    array.append(encoded ?? .Nil)
  }

  private func encodeUInt(_ value: some UnsignedInteger & FixedWidthInteger) throws {
    try array.append(encoder.wrapUInt(value, for: nil))
  }

  private func encodeInt(_ value: some SignedInteger & FixedWidthInteger) throws {
    try array.append(encoder.wrapInt(value, for: nil))
  }

  private func encodeFloat(_ value: some BinaryFloatingPoint & DataNumber) throws {
    try array.append(encoder.wrapFloat(value, for: nil))
  }

  func nestedContainer<NestedKey>(keyedBy _: NestedKey.Type) -> KeyedEncodingContainer<NestedKey>
  where NestedKey: CodingKey {
    let newPath = codingPath + [CborKey(index: count)]
    let map = array.appendMap()
    let nestedContainer = CborKeyedEncodingContainer<NestedKey>(
      referencing: encoder, map: map, codingPath: newPath)
    return KeyedEncodingContainer(nestedContainer)
  }

  func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
    let newPath = codingPath + [CborKey(index: count)]
    let array = array.appendArray()
    let nestedContainer = CborUnkeyedEncodingContainer(
      referencing: encoder, array: array, codingPath: newPath)
    return nestedContainer
  }

  func superEncoder() -> Encoder {
    let encoder = encoder.getEncoder(for: CborKey(index: count))
    array.append(encoder)
    return encoder
  }
}

private struct CborKeyedEncodingContainer<K: CodingKey>: KeyedEncodingContainerProtocol {
  typealias Key = K

  private let encoder: _CborEncoder
  let map: CborFuture.RefMap
  private(set) var codingPath: [CodingKey]

  init(referencing encoder: _CborEncoder, codingPath: [CodingKey]) {
    self.encoder = encoder
    self.codingPath = codingPath
    map = encoder.map!
  }

  init(referencing encoder: _CborEncoder, map: CborFuture.RefMap, codingPath: [CodingKey]) {
    self.encoder = encoder
    self.codingPath = codingPath
    self.map = map
  }

  func encodeNil(forKey key: Key) throws {
    try map.set(.Nil, for: encoder.wrapStringKey(key.stringValue, for: key))
  }

  func encode(_ value: Bool, forKey key: Key) throws {
    let value = encoder.wrapBool(value)
    try map.set(value, for: encoder.wrapStringKey(key.stringValue, for: key))
  }

  func encode(_ value: String, forKey key: Key) throws {
    let value = try encoder.wrapString(value, for: key)
    try map.set(value, for: encoder.wrapStringKey(key.stringValue, for: key))
  }

  func encode(_ value: Double, forKey key: Key) throws {
    try encodeFloat(value, for: key)
  }

  func encode(_ value: Float, forKey key: Key) throws {
    try encodeFloat(value, for: key)
  }

  func encode(_ value: Int, forKey key: Key) throws {
    try encodeInt(value, for: key)
  }

  func encode(_ value: Int8, forKey key: Key) throws {
    try encodeInt(value, for: key)
  }

  func encode(_ value: Int16, forKey key: Key) throws {
    try encodeInt(value, for: key)
  }

  func encode(_ value: Int32, forKey key: Key) throws {
    try encodeInt(value, for: key)
  }

  func encode(_ value: Int64, forKey key: Key) throws {
    try encodeInt(value, for: key)
  }

  func encode(_ value: UInt, forKey key: Key) throws {
    try encodeUInt(value, forKey: key)
  }

  func encode(_ value: UInt8, forKey key: Key) throws {
    try encodeUInt(value, forKey: key)
  }

  func encode(_ value: UInt16, forKey key: Key) throws {
    try encodeUInt(value, forKey: key)
  }

  func encode(_ value: UInt32, forKey key: Key) throws {
    try encodeUInt(value, forKey: key)
  }

  func encode(_ value: UInt64, forKey key: Key) throws {
    try encodeUInt(value, forKey: key)
  }

  func encode(_ value: some Encodable, forKey key: Key) throws {
    let encoded = try encoder.wrapEncodable(value, for: key)
    try map.set(encoded ?? .Nil, for: encoder.wrapStringKey(key.stringValue, for: key))
  }

  func nestedContainer<NestedKey>(keyedBy _: NestedKey.Type, forKey key: Key)
    -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey
  {
    let newPath = codingPath + [key]
    let map: CborFuture.RefMap = map.setMap(
      for: try! encoder.wrapStringKey(key.stringValue, for: key))
    let nestedContainer = CborKeyedEncodingContainer<NestedKey>(
      referencing: encoder, map: map, codingPath: newPath)
    return KeyedEncodingContainer(nestedContainer)
  }

  func nestedUnkeyedContainer(forKey key: Self.Key) -> UnkeyedEncodingContainer {
    let newPath = codingPath + [key]
    let array: CborFuture.RefArray = map.setArray(
      for: try! encoder.wrapStringKey(key.stringValue, for: key))
    let nestedContainer = CborUnkeyedEncodingContainer(
      referencing: encoder, array: array, codingPath: newPath)
    return nestedContainer
  }

  func superEncoder() -> Encoder {
    let newEncoder = encoder.getEncoder(for: CborKey.super)
    map.set(newEncoder, for: try! encoder.wrapStringKey(CborKey.super.stringValue, for: nil))
    return newEncoder
  }

  func superEncoder(forKey key: Key) -> Encoder {
    let newEncoder = encoder.getEncoder(for: key)
    map.set(newEncoder, for: try! encoder.wrapStringKey(key.stringValue, for: key))
    return newEncoder
  }

  private func encodeFloat(_ value: some BinaryFloatingPoint & DataNumber, for key: Key) throws {
    let value = try encoder.wrapFloat(value, for: nil)
    try map.set(value, for: encoder.wrapStringKey(key.stringValue, for: key))
  }

  private func encodeInt(_ value: some SignedInteger & FixedWidthInteger, for key: Key) throws {
    let value = try encoder.wrapInt(value, for: key)
    try map.set(value, for: encoder.wrapStringKey(key.stringValue, for: key))
  }

  private func encodeUInt(_ value: some UnsignedInteger & FixedWidthInteger, forKey key: Key) throws
  {
    let value = try encoder.wrapUInt(value, for: key)
    try map.set(value, for: encoder.wrapStringKey(key.stringValue, for: key))
  }
}

struct CborKey: CodingKey {
  public var stringValue: String
  public var intValue: Int?

  public init(stringValue: String) {
    self.stringValue = stringValue
    intValue = nil
  }

  public init?(intValue: Int) {
    stringValue = intValue.description
    self.intValue = intValue
  }

  init(index: Int) {
    stringValue = "Index \(index)"
    intValue = index
  }

  static let `super`: CborKey = .init(stringValue: "super")
}

func bigEndianFixedWidthInt<T: FixedWidthInteger>(_ data: Data, as _: T.Type) -> T {
  T(
    bigEndian: data.withUnsafeBytes { $0.baseAddress?.assumingMemoryBound(to: T.self).pointee ?? 0 }
  )
}

extension Int {
  static let fixMax = 0x17
}
