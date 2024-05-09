import Foundation

private protocol _CborDictionaryDecodableMarker {}

extension Dictionary: _CborDictionaryDecodableMarker where Key: Encodable, Value: Decodable {}

private protocol _CborArrayDecodableMarker {}

extension Array: _CborArrayDecodableMarker where Element: Decodable {}

open class CborDecoder {
    public init() {}
    open func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let scanner = CborScanner(data: data)
        let value = try scanner.scan()
        let decoder: _CborDecoder = .init(from: value)
        do {
            return try decoder.unwrap(as: T.self)
        } catch {
            if let error = error as? CborDecodingError {
                throw error.asDecodingError(type, codingPath: [])
            }
            throw error
        }
    }
}

private class _CborDecoder: Decoder {
    var codingPath: [CodingKey]
    var value: CborValue
    var userInfo: [CodingUserInfoKey: Any] = [:]

    init(from value: CborValue, at codingPath: [CodingKey] = []) {
        self.value = value
        self.codingPath = codingPath
    }

    func container<Key>(keyedBy _: Key.Type) throws -> KeyedDecodingContainer<Key> where Key: CodingKey {
        guard case .map = value else {
            throw DecodingError.typeMismatch([String: Any].self, DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Expected to decode \([String: Any].self) but found \(value.debugDataTypeDescription) instead."
            ))
        }
        return KeyedDecodingContainer(CborKeyedDecodingContainer<Key>(referencing: self, container: value))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        switch value {
        case .array, .map, .none: break
        default:
            throw DecodingError.typeMismatch([Any].self, DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Expected to decode \([Any].self) but found \(value.debugDataTypeDescription) instead."
            ))
        }

        return CborUnkeyedUnkeyedDecodingContainer(referencing: self, container: value)
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        _CborSingleValueDecodingContainer(decoder: self, codingPath: codingPath, value: value)
    }
}

private extension _CborDecoder {
    func unbox(_ value: CborValue, as type: Bool.Type) throws -> Bool? {
        if case let .literal(value) = value {
            switch value {
            case let .bool(v): return v
            case .nil: return nil
            default:
                break
            }
        }
        throw DecodingError.typeMismatch(type, DecodingError.Context(
            codingPath: codingPath,
            debugDescription: "Expected to decode \(type) but found \(value.debugDataTypeDescription) instead."
        ))
    }

    func unbox(_ value: CborValue, as type: String.Type) throws -> String? {
        if case let .literal(value) = value {
            switch value {
            case let .str(v):
                return String(data: v, encoding: .utf8)
            case .nil:
                return nil
            default:
                break
            }
        }
        throw DecodingError.typeMismatch(type, DecodingError.Context(
            codingPath: codingPath,
            debugDescription: "Expected to decode \(type) but found \(value.debugDataTypeDescription) instead."
        ))
    }

    func unboxFloat<T: BinaryFloatingPoint & DataNumber>(_ value: CborValue, as type: T.Type) throws -> T? {
        if case let .literal(f) = value {
            switch f {
            case let .float16(v):
                return try T(Float16(data: v))
            case let .float32(v):
                return try T(Float(data: v))
            case let .float64(v):
                return try T(Double(data: v))
            case .nil:
                return nil
            default:
                break
            }
        }
        throw DecodingError.typeMismatch(type, DecodingError.Context(
            codingPath: codingPath,
            debugDescription: "Expected to decode \(type) but found \(value.debugDataTypeDescription) instead."
        ))
    }

    func unboxInt(_ value: CborValue) throws -> Int {
        if case let .literal(vv) = value {
            switch vv {
            case let .uint(data, type):
                return Int(bigEndianFixedWidthInt(data, as: type))
            case let .int(data, type):
                return ~Int(bigEndianFixedWidthInt(data, as: type))
            default:
                break
            }
        }

        throw DecodingError.typeMismatch(Int.self, DecodingError.Context(
            codingPath: codingPath,
            debugDescription: "Expected to decode \(Int.self) but found \(value.debugDataTypeDescription) instead."
        ))
    }

    func unboxInt8(_ value: CborValue) throws -> Int8 {
        if case let .literal(vv) = value {
            switch vv {
            case let .uint(data, type):
                return Int8(truncatingIfNeeded: bigEndianFixedWidthInt(data, as: type))
            case let .int(data, type):
                return ~Int8(truncatingIfNeeded: bigEndianFixedWidthInt(data, as: type))
            default:
                break
            }
        }

        throw DecodingError.typeMismatch(Int8.self, DecodingError.Context(
            codingPath: codingPath,
            debugDescription: "Expected to decode \(Int8.self) but found \(value.debugDataTypeDescription) instead."
        ))
    }

    func unboxInt16(_ value: CborValue) throws -> Int16 {
        if case let .literal(vv) = value {
            switch vv {
            case let .uint(data, type):
                return Int16(truncatingIfNeeded: bigEndianFixedWidthInt(data, as: type))
            case let .int(data, type):
                return ~Int16(truncatingIfNeeded: bigEndianFixedWidthInt(data, as: type))
            default:
                break
            }
        }

        throw DecodingError.typeMismatch(Int16.self, DecodingError.Context(
            codingPath: codingPath,
            debugDescription: "Expected to decode \(Int16.self) but found \(value.debugDataTypeDescription) instead."
        ))
    }

    func unboxInt32(_ value: CborValue) throws -> Int32 {
        if case let .literal(vv) = value {
            switch vv {
            case let .uint(data, type):
                return Int32(truncatingIfNeeded: bigEndianFixedWidthInt(data, as: type))
            case let .int(data, type):
                return ~Int32(truncatingIfNeeded: bigEndianFixedWidthInt(data, as: type))
            default:
                break
            }
        }

        throw DecodingError.typeMismatch(Int32.self, DecodingError.Context(
            codingPath: codingPath,
            debugDescription: "Expected to decode \(Int32.self) but found \(value.debugDataTypeDescription) instead."
        ))
    }

    func unboxInt64(_ value: CborValue) throws -> Int64 {
        if case let .literal(vv) = value {
            switch vv {
            case let .uint(data, type):
                return Int64(truncatingIfNeeded: bigEndianFixedWidthInt(data, as: type))
            case let .int(data, type):
                return ~Int64(truncatingIfNeeded: bigEndianFixedWidthInt(data, as: type))
            default:
                break
            }
        }

        throw DecodingError.typeMismatch(Int64.self, DecodingError.Context(
            codingPath: codingPath,
            debugDescription: "Expected to decode \(Int64.self) but found \(value.debugDataTypeDescription) instead."
        ))
    }

    func unboxUInt(_ value: CborValue) throws -> UInt {
        if case let .literal(literal) = value {
            switch literal {
            case let .uint(data, type):
                return UInt(truncatingIfNeeded: bigEndianFixedWidthInt(data, as: type))
            default:
                break
            }
        }

        throw DecodingError.typeMismatch(UInt.self, DecodingError.Context(
            codingPath: codingPath,
            debugDescription: "Expected to decode \(UInt.self) but found \(value.debugDataTypeDescription) instead."
        ))
    }

    func unboxUInt8(_ value: CborValue) throws -> UInt8 {
        if case let .literal(literal) = value {
            switch literal {
            case let .uint(data, type):
                return UInt8(bigEndianFixedWidthInt(data, as: type))
            default:
                break
            }
        }

        throw DecodingError.typeMismatch(UInt8.self, DecodingError.Context(
            codingPath: codingPath,
            debugDescription: "Expected to decode \(UInt8.self) but found \(value.debugDataTypeDescription) instead."
        ))
    }

    func unboxUInt16(_ value: CborValue) throws -> UInt16 {
        if case let .literal(literal) = value {
            switch literal {
            case let .uint(data, type):
                return UInt16(truncatingIfNeeded: bigEndianFixedWidthInt(data, as: type))
            default:
                break
            }
        }

        throw DecodingError.typeMismatch(UInt16.self, DecodingError.Context(
            codingPath: codingPath,
            debugDescription: "Expected to decode \(UInt16.self) but found \(value.debugDataTypeDescription) instead."
        ))
    }

    func unboxUInt32(_ value: CborValue) throws -> UInt32 {
        if case let .literal(literal) = value {
            switch literal {
            case let .uint(data, type):
                return UInt32(truncatingIfNeeded: bigEndianFixedWidthInt(data, as: type))
            default:
                break
            }
        }

        throw DecodingError.typeMismatch(UInt32.self, DecodingError.Context(
            codingPath: codingPath,
            debugDescription: "Expected to decode \(UInt32.self) but found \(value.debugDataTypeDescription) instead."
        ))
    }

    func unboxUInt64(_ value: CborValue) throws -> UInt64 {
        if case let .literal(literal) = value {
            switch literal {
            case let .uint(data, type):
                return UInt64(truncatingIfNeeded: bigEndianFixedWidthInt(data, as: type))
            default:
                break
            }
        }

        throw DecodingError.typeMismatch(UInt64.self, DecodingError.Context(
            codingPath: codingPath,
            debugDescription: "Expected to decode \(UInt64.self) but found \(value.debugDataTypeDescription) instead."
        ))
    }
}

extension _CborDecoder {
    func unwrap<T: Decodable>(as type: T.Type) throws -> T {
        if type == Data.self || type == NSData.self {
            return try unwrapData() as! T
        }
        if let type = type as? CborDecodable.Type {
            let value = try unwrapCborDecodable(as: type)
            return value as! T
        }
        if T.self is _CborDictionaryDecodableMarker.Type {
            try checkDictionay(as: T.self)
        }
        if T.self is _CborArrayDecodableMarker.Type {
            try checkArray(as: T.self)
        }
        return try T(from: self)
    }

    func unwrapData() throws -> Data {
        switch value {
        case let .literal(.bin(v)) /* , let .literal(.str(v))*/:
            v
        default:
            throw DecodingError.typeMismatch(Data.self, DecodingError.Context(codingPath: codingPath, debugDescription: ""))
        }
    }

    func unwrapCborDecodable(as type: CborDecodable.Type) throws -> CborDecodable {
        guard case let .tagged(tagData, cborValue) = value else {
            throw DecodingError.typeMismatch(CborDecodable.self, DecodingError.Context(codingPath: codingPath, debugDescription: ""))
        }
        let tag = try unboxUInt64(.literal(tagData))
        let value = try type.init(from: _CborDecoder(from: cborValue))
        guard value.tag == tag else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: codingPath, debugDescription: "tag number mismatch: expected: \(value.tag) got: \(tag)"))
        }
        return value
    }

    private func checkDictionay<T: Decodable>(as _: T.Type) throws {
        guard (T.self as? (_CborDictionaryDecodableMarker & Decodable).Type) != nil else {
            preconditionFailure("Must only be called of T implements _CborDictionaryDecodableMarker")
        }
        guard case .map = value else {
            throw DecodingError.typeMismatch(T.self, DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Expected to decode \(T.self) but found \(value.debugDataTypeDescription) instead."
            ))
        }
    }

    private func checkArray<T: Decodable>(as _: T.Type) throws {
        guard (T.self as? (_CborArrayDecodableMarker & Decodable).Type) != nil else {
            preconditionFailure("Must only be called of T implements _CborArrayDecodableMarker")
        }
        guard case .array = value else {
            throw DecodingError.typeMismatch([CborValue].self, DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Expected to decode \([CborValue].self) but found \(value.debugDataTypeDescription) instead."
            ))
        }
    }
}

private struct _CborSingleValueDecodingContainer: SingleValueDecodingContainer {
    let decoder: _CborDecoder
    let codingPath: [CodingKey]
    let value: CborValue

    init(decoder: _CborDecoder, codingPath: [CodingKey], value: CborValue) {
        self.decoder = decoder
        self.codingPath = codingPath
        self.value = value
    }

    func decodeNil() -> Bool {
        if case .literal(.nil) = value {
            true
        } else {
            false
        }
    }

    func decode(_: Bool.Type) throws -> Bool {
        try decoder.unbox(value, as: Bool.self)!
    }

    func decode(_ type: String.Type) throws -> String {
        try decoder.unbox(value, as: type)!
    }

    func decode(_ type: Double.Type) throws -> Double {
        try decoder.unboxFloat(value, as: type)!
    }

    func decode(_ type: Float.Type) throws -> Float {
        try decoder.unboxFloat(value, as: type)!
    }

    func decode(_: Int.Type) throws -> Int {
        try decoder.unboxInt(value)
    }

    func decode(_: Int8.Type) throws -> Int8 {
        try decoder.unboxInt8(value)
    }

    func decode(_: Int16.Type) throws -> Int16 {
        try decoder.unboxInt16(value)
    }

    func decode(_: Int32.Type) throws -> Int32 {
        try decoder.unboxInt32(value)
    }

    func decode(_: Int64.Type) throws -> Int64 {
        try decoder.unboxInt64(value)
    }

    func decode(_: UInt.Type) throws -> UInt {
        try decoder.unboxUInt(value)
    }

    func decode(_: UInt8.Type) throws -> UInt8 {
        try decoder.unboxUInt8(value)
    }

    func decode(_: UInt16.Type) throws -> UInt16 {
        try decoder.unboxUInt16(value)
    }

    func decode(_: UInt32.Type) throws -> UInt32 {
        try decoder.unboxUInt32(value)
    }

    func decode(_: UInt64.Type) throws -> UInt64 {
        try decoder.unboxUInt64(value)
    }

    func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        try decoder.unwrap(as: type)
    }
}

private struct CborUnkeyedUnkeyedDecodingContainer: UnkeyedDecodingContainer {
    private let decoder: _CborDecoder
    private(set) var codingPath: [CodingKey]
    public private(set) var currentIndex: Int
    private var container: [CborValue]

    init(referencing decoder: _CborDecoder, container: CborValue) {
        self.decoder = decoder
        codingPath = decoder.codingPath
        currentIndex = 0
        self.container = container.asArray()
    }

    var count: Int? {
        container.count
    }

    var isAtEnd: Bool {
        currentIndex >= count!
    }

    mutating func decodeNil() throws -> Bool {
        let value = try getNextValue(ofType: Never.self)
        if case .literal(.nil) = value {
            currentIndex += 1
            return true
        }
        return false
    }

    mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
        let decoder = try decoderForNextElement(ofType: UnkeyedDecodingContainer.self)
        let container: KeyedDecodingContainer = try decoder.container(keyedBy: type)
        currentIndex += 1
        return container
    }

    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        let decoder = try decoderForNextElement(ofType: UnkeyedDecodingContainer.self)
        let container: UnkeyedDecodingContainer = try decoder.unkeyedContainer()
        currentIndex += 1
        return container
    }

    mutating func superDecoder() throws -> Decoder {
        let decoder = try decoderForNextElement(ofType: Decoder.self)
        currentIndex += 1
        return decoder
    }

    mutating func decode(_: Bool.Type) throws -> Bool {
        let value = try getNextValue(ofType: String.self)
        currentIndex += 1
        return try decoder.unbox(value, as: Bool.self)!
    }

    mutating func decode(_: String.Type) throws -> String {
        let value = try getNextValue(ofType: String.self)
        currentIndex += 1
        return try decoder.unbox(value, as: String.self)!
    }

    mutating func decode(_: Double.Type) throws -> Double {
        try decodeFloat(as: Double.self)
    }

    mutating func decode(_: Float.Type) throws -> Float {
        try decodeFloat(as: Float.self)
    }

    mutating func decode(_: Int.Type) throws -> Int {
        try decodeInt()
    }

    mutating func decode(_: Int8.Type) throws -> Int8 {
        try decodeInt8()
    }

    mutating func decode(_: Int16.Type) throws -> Int16 {
        try decodeInt16()
    }

    mutating func decode(_: Int32.Type) throws -> Int32 {
        try decodeInt32()
    }

    mutating func decode(_: Int64.Type) throws -> Int64 {
        try decodeInt64()
    }

    mutating func decode(_: UInt.Type) throws -> UInt {
        try decodeUInt()
    }

    mutating func decode(_: UInt8.Type) throws -> UInt8 {
        try decodeUInt8()
    }

    mutating func decode(_: UInt16.Type) throws -> UInt16 {
        try decodeUInt16()
    }

    mutating func decode(_: UInt32.Type) throws -> UInt32 {
        try decodeUInt32()
    }

    mutating func decode64(_: UInt64.Type) throws -> UInt64 {
        try decodeUInt64()
    }

    mutating func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        let newDecoder: _CborDecoder = try decoderForNextElement(ofType: T.self)
        do {
            let result: T = try newDecoder.unwrap(as: T.self)
            currentIndex += 1
            return result
        } catch {
            if let error = error as? CborDecodingError {
                throw error.asDecodingError(type, codingPath: codingPath)
            }
            throw error
        }
    }

    private mutating func decoderForNextElement<T>(ofType _: T.Type) throws -> _CborDecoder {
        let value = try getNextValue(ofType: T.self)
        let newPath = codingPath + [CborKey(index: currentIndex)]
        return _CborDecoder(from: value, at: newPath)
    }

    @inline(__always)
    private func getNextValue<T>(ofType _: T.Type) throws -> CborValue {
        guard !isAtEnd else {
            let message = if T.self == CborUnkeyedUnkeyedDecodingContainer.self {
                "Cannot get nested unkeyed container -- unkeyed container is at end."
            } else if T.self == Decoder.self {
                "Cannot get superDecoder() -- unkeyed container is at end."
            } else {
                "Unkeyed container is at end."
            }

            var path = codingPath
            path.append(CborKey(index: currentIndex))

            throw DecodingError.valueNotFound(
                T.self,
                .init(codingPath: path,
                      debugDescription: message,
                      underlyingError: nil)
            )
        }
        return container[currentIndex]
    }

    @inline(__always)
    private mutating func decodeUInt() throws -> UInt {
        let value = try getNextValue(ofType: UInt.self)
        let result = try decoder.unboxUInt(value)
        currentIndex += 1
        return result
    }

    @inline(__always)
    private mutating func decodeUInt8() throws -> UInt8 {
        let value = try getNextValue(ofType: UInt8.self)
        let result = try decoder.unboxUInt8(value)
        currentIndex += 1
        return result
    }

    @inline(__always)
    private mutating func decodeUInt16() throws -> UInt16 {
        let value = try getNextValue(ofType: UInt16.self)
        let result = try decoder.unboxUInt16(value)
        currentIndex += 1
        return result
    }

    @inline(__always)
    private mutating func decodeUInt32() throws -> UInt32 {
        let value = try getNextValue(ofType: UInt32.self)
        let result = try decoder.unboxUInt32(value)
        currentIndex += 1
        return result
    }

    @inline(__always)
    private mutating func decodeUInt64() throws -> UInt64 {
        let value = try getNextValue(ofType: UInt64.self)
        let result = try decoder.unboxUInt64(value)
        currentIndex += 1
        return result
    }

    @inline(__always)
    private mutating func decodeInt() throws -> Int {
        let value = try getNextValue(ofType: Int.self)
        let result = try decoder.unboxInt(value)
        currentIndex += 1
        return result
    }

    @inline(__always)
    private mutating func decodeInt8() throws -> Int8 {
        let value = try getNextValue(ofType: Int8.self)
        let result = try decoder.unboxInt8(value)
        currentIndex += 1
        return result
    }

    @inline(__always)
    private mutating func decodeInt16() throws -> Int16 {
        let value = try getNextValue(ofType: Int16.self)
        let result = try decoder.unboxInt16(value)
        currentIndex += 1
        return result
    }

    @inline(__always)
    private mutating func decodeInt32() throws -> Int32 {
        let value = try getNextValue(ofType: Int32.self)
        let result = try decoder.unboxInt32(value)
        currentIndex += 1
        return result
    }

    @inline(__always)
    private mutating func decodeInt64() throws -> Int64 {
        let value = try getNextValue(ofType: Int64.self)
        let result = try decoder.unboxInt64(value)
        currentIndex += 1
        return result
    }

    @inline(__always)
    private mutating func decodeFloat<T: BinaryFloatingPoint & DataNumber>(as _: T.Type) throws -> T {
        let value = try getNextValue(ofType: T.self)
        let result = try decoder.unboxFloat(value, as: T.self)!
        currentIndex += 1
        return result
    }
}

private struct CborKeyedDecodingContainer<K: CodingKey>: KeyedDecodingContainerProtocol {
    typealias Key = K

    private let decoder: _CborDecoder
    private(set) var codingPath: [CodingKey]
    private var container: [String: CborValue]

    static func asDictionary(value CborValue: CborValue, using decoder: _CborDecoder) -> [String: CborValue] {
        var result: [String: CborValue] = [:]
        let a = CborValue.asDictionary()
        result.reserveCapacity(a.count)
        for (keyvalue, value) in a {
            guard let key = try? decoder.unbox(keyvalue, as: String.self) else {
                continue
            }
            result[key]._setIfNil(to: value)
        }

        return result
    }

    init(referencing decoder: _CborDecoder, container: CborValue) {
        self.decoder = decoder
        self.container = Self.asDictionary(value: container, using: decoder)
        codingPath = decoder.codingPath
    }

    var allKeys: [Key] {
        container.keys.compactMap {
            Key(stringValue: $0)
        }
    }

    func contains(_ key: Key) -> Bool {
        container[key.stringValue] != nil
    }

    func decodeNil(forKey key: Key) throws -> Bool {
        let value = try getValue(forKey: key)
        if case .literal(.nil) = value {
            return true
        } else {
            return false
        }
    }

    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        let value = try getValue(forKey: key)
        return try decoder.unbox(value, as: type)!
    }

    func decode(_ type: String.Type, forKey key: Key) throws -> String {
        let value = try getValue(forKey: key)
        return try decoder.unbox(value, as: type)!
    }

    func decode(_: Double.Type, forKey key: Key) throws -> Double {
        try decodeFloat(key: key)
    }

    func decode(_: Float.Type, forKey key: Key) throws -> Float {
        try decodeFloat(key: key)
    }

    func decode(_: Int.Type, forKey key: Key) throws -> Int {
        try decodeInt(key: key)
    }

    func decode(_: Int8.Type, forKey key: Key) throws -> Int8 {
        try decodeInt8(key: key)
    }

    func decode(_: Int16.Type, forKey key: Key) throws -> Int16 {
        try decodeInt16(key: key)
    }

    func decode(_: Int32.Type, forKey key: Key) throws -> Int32 {
        try decodeInt32(key: key)
    }

    func decode(_: Int64.Type, forKey key: Key) throws -> Int64 {
        try decodeInt64(key: key)
    }

    func decode(_: UInt.Type, forKey key: Key) throws -> UInt {
        try decodeUInt(key: key)
    }

    func decode(_: UInt8.Type, forKey key: Key) throws -> UInt8 {
        try decodeUInt8(key: key)
    }

    func decode(_: UInt16.Type, forKey key: Key) throws -> UInt16 {
        try decodeUInt16(key: key)
    }

    func decode(_: UInt32.Type, forKey key: Key) throws -> UInt32 {
        try decodeUInt32(key: key)
    }

    func decode(_: UInt64.Type, forKey key: Key) throws -> UInt64 {
        try decodeUInt64(key: key)
    }

    func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T: Decodable {
        let newDecoder: _CborDecoder = try decoderForKey(key)
        do {
            return try newDecoder.unwrap(as: T.self)
        } catch {
            if let error = error as? CborDecodingError {
                throw error.asDecodingError(type, codingPath: codingPath)
            }
            throw error
        }
    }

    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
        try decoderForKey(key).container(keyedBy: type)
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        try decoderForKey(key).unkeyedContainer()
    }

    func superDecoder() throws -> Decoder {
        try decoderForKey(CborKey.super)
    }

    func superDecoder(forKey key: Key) throws -> Decoder {
        try decoderForKey(key)
    }

    private func decoderForKey(_ key: some CodingKey) throws -> _CborDecoder {
        let value = try getValue(forKey: key)
        let newPath: [CodingKey] = codingPath + [key]
        return _CborDecoder(from: value, at: newPath)
    }

    @inline(__always)
    private func getValue<LocalKey: CodingKey>(forKey key: LocalKey) throws -> CborValue {
        guard let value = container[key.stringValue] else {
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: "No value assosiated with key \(key) (\"\(key.stringValue)\"")
            throw DecodingError.keyNotFound(key, context)
        }
        return value
    }

    @inline(__always)
    private func decodeFloat<T: BinaryFloatingPoint & DataNumber>(key: K) throws -> T {
        let value = try getValue(forKey: key)
        return try decoder.unboxFloat(value, as: T.self)!
    }

    @inline(__always)
    private func decodeInt(key: K) throws -> Int {
        let value = try getValue(forKey: key)
        do {
            return try decoder.unboxInt(value)
        } catch {
            if let error = error as? CborDecodingError {
                throw error.asDecodingError(Int.self, codingPath: codingPath)
            }
            throw error
        }
    }

    @inline(__always)
    private func decodeInt8(key: K) throws -> Int8 {
        let value = try getValue(forKey: key)
        do {
            return try decoder.unboxInt8(value)
        } catch {
            if let error = error as? CborDecodingError {
                throw error.asDecodingError(Int8.self, codingPath: codingPath)
            }
            throw error
        }
    }

    @inline(__always)
    private func decodeInt16(key: K) throws -> Int16 {
        let value = try getValue(forKey: key)
        do {
            return try decoder.unboxInt16(value)
        } catch {
            if let error = error as? CborDecodingError {
                throw error.asDecodingError(Int16.self, codingPath: codingPath)
            }
            throw error
        }
    }

    @inline(__always)
    private func decodeInt32(key: K) throws -> Int32 {
        let value = try getValue(forKey: key)
        do {
            return try decoder.unboxInt32(value)
        } catch {
            if let error = error as? CborDecodingError {
                throw error.asDecodingError(Int32.self, codingPath: codingPath)
            }
            throw error
        }
    }

    @inline(__always)
    private func decodeInt64(key: K) throws -> Int64 {
        let value = try getValue(forKey: key)
        do {
            return try decoder.unboxInt64(value)
        } catch {
            if let error = error as? CborDecodingError {
                throw error.asDecodingError(Int64.self, codingPath: codingPath)
            }
            throw error
        }
    }

    @inline(__always)
    private func decodeUInt(key: K) throws -> UInt {
        let value = try getValue(forKey: key)
        do {
            return try decoder.unboxUInt(value)
        } catch {
            if let error = error as? CborDecodingError {
                throw error.asDecodingError(UInt.self, codingPath: codingPath)
            }
            throw error
        }
    }

    @inline(__always)
    private func decodeUInt8(key: K) throws -> UInt8 {
        let value = try getValue(forKey: key)
        do {
            return try decoder.unboxUInt8(value)
        } catch {
            if let error = error as? CborDecodingError {
                throw error.asDecodingError(UInt8.self, codingPath: codingPath)
            }
            throw error
        }
    }

    @inline(__always)
    private func decodeUInt16(key: K) throws -> UInt16 {
        let value = try getValue(forKey: key)
        do {
            return try decoder.unboxUInt16(value)
        } catch {
            if let error = error as? CborDecodingError {
                throw error.asDecodingError(UInt16.self, codingPath: codingPath)
            }
            throw error
        }
    }

    @inline(__always)
    private func decodeUInt32(key: K) throws -> UInt32 {
        let value = try getValue(forKey: key)
        do {
            return try decoder.unboxUInt32(value)
        } catch {
            if let error = error as? CborDecodingError {
                throw error.asDecodingError(UInt32.self, codingPath: codingPath)
            }
            throw error
        }
    }

    @inline(__always)
    private func decodeUInt64(key: K) throws -> UInt64 {
        let value = try getValue(forKey: key)
        do {
            return try decoder.unboxUInt64(value)
        } catch {
            if let error = error as? CborDecodingError {
                throw error.asDecodingError(UInt64.self, codingPath: codingPath)
            }
            throw error
        }
    }
}

enum CborDecodingError: Error {
    case dataCorrupted
}

extension CborDecodingError {
    func asDecodingError(_ type: (some Any).Type, codingPath: [CodingKey]) -> DecodingError {
        switch self {
        case .dataCorrupted:
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: "Expected to decode \(type) but it failed")
            return DecodingError.dataCorrupted(context)
        }
    }
}

private extension Optional {
    mutating func _setIfNil(to value: Wrapped) {
        guard _fastPath(self == nil) else { return }
        self = value
    }
}
