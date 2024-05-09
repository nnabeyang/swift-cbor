public protocol CborEncodable: Encodable {
    var tag: UInt64 { get }
}

public protocol CborDecodable: Decodable {
    var tag: UInt64 { get }
}

public typealias CborCodable = CborDecodable & CborEncodable
