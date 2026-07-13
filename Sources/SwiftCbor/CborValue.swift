import Foundation

enum CborValueLiteralType {
  case `nil`
  case `break`
  case bool(Bool)
  case int(UInt64)
  case uint(UInt64)
  case float16(Data)
  case float32(Data)
  case float64(Data)
  case str(Data)
  case bin(Data)
}

extension CborValueLiteralType {
  var debugDataTypeDescription: String {
    switch self {
    case .nil:
      "nil"
    case .break:
      "break"
    case .bool:
      "bool"
    case .int:
      "int"
    case .uint:
      "uint"
    case .float16:
      "float16"
    case .float32:
      "float32"
    case .float64:
      "float64"
    case .str:
      "str"
    case .bin:
      "bin"
    }
  }
}

indirect enum CborEncodedValue: Sendable {
  case none
  case literal([UInt8])
  case array([CborEncodedValue])
  case map([CborEncodedValue])
  case tagged(tag: CborEncodedValue, value: CborEncodedValue)

  static let Nil = literal([0xF6])

  var debugDataTypeDescription: String {
    switch self {
    case .none: "nil"
    case .literal: "literal"
    case .array: "array"
    case .map: "map"
    case .tagged: "tagged"
    }
  }
}

extension CborEncodedValue {
  func asMap() -> CborEncodedValue {
    switch self {
    case .none, .literal, .tagged:
      return .map([])
    case .array(let a):
      if a.count % 2 != 0 {
        return .map([])
      }
      return .map(a)
    case .map:
      return self
    }
  }
}

struct CborStringKey {
  let stringValue: String
  let CborValue: CborEncodedValue
}

indirect enum CborValue {
  case none
  case literal(CborValueLiteralType)
  case array([CborValue])
  case map([CborValue])
  case tagged(tag: CborValueLiteralType, value: CborValue)
}

extension CborValue {
  func asArray() -> [CborValue] {
    switch self {
    case .none:
      []
    case .literal, .tagged:
      [self]
    case .array(let a), .map(let a):
      a
    }
  }

  func asDictionary() -> [(CborValue, CborValue)] {
    switch self {
    case .none, .literal, .tagged:
      return []
    case .array(let a):
      if a.count % 2 != 0 {
        return []
      }
      let n = a.count / 2
      var d = [(CborValue, CborValue)]()
      d.reserveCapacity(n * 2)
      for i in 0..<n {
        let key = a[i * 2]
        let value = a[i * 2 + 1]
        d.append((key, value))
      }
      return d
    case .map(let a):
      let n = a.count / 2
      var d = [(CborValue, CborValue)]()
      d.reserveCapacity(n * 2)
      for i in 0..<n {
        let key = a[i * 2]
        let value = a[i * 2 + 1]
        d.append((key, value))
      }
      return d
    }
  }
}

extension CborValue {
  var debugDataTypeDescription: String {
    switch self {
    case .none:
      "none"
    case .literal(let v):
      v.debugDataTypeDescription
    case .array:
      "an array"
    case .map:
      "a map"
    case .tagged:
      "a tagged value"
    }
  }
}

extension CborValue {
  struct Writer {
    private let sortMapKeysLexicographically: Bool

    init(sortMapKeysLexicographically: Bool = false) {
      self.sortMapKeysLexicographically = sortMapKeysLexicographically
    }

    func writeValue(_ value: CborEncodedValue) -> [UInt8] {
      var bytes: [UInt8] = .init()
      writeValue(value, into: &bytes)
      return bytes
    }

    private func writeValue(_ value: CborEncodedValue, into bytes: inout [UInt8]) {
      switch value {
      case .literal(let data):
        bytes.append(contentsOf: data)
      case .tagged(let tag, let value):
        writeValue(tag, into: &bytes)
        writeValue(value, into: &bytes)
      case .array(let array):
        let n = array.count
        if n <= Int.fixMax {
          bytes.append(contentsOf: [UInt8(0x80 + n)])
        } else if n <= UInt8.max {
          bytes.append(contentsOf: [UInt8(0x98), UInt8(n)])
        } else if n <= UInt16.max {
          bytes.append(contentsOf: [UInt8(0x99)] + n.bigEndianBytes(as: UInt16.self))
        } else if n <= UInt32.max {
          bytes.append(contentsOf: [UInt8(0x9A)] + n.bigEndianBytes(as: UInt32.self))
        } else if n <= Int.max {
          bytes.append(contentsOf: [UInt8(0x9B)] + n.bigEndianBytes(as: UInt64.self))
        }
        for item in array {
          writeValue(item, into: &bytes)
        }
      case .map(let a):
        let n = a.count / 2
        if n <= Int.fixMax {
          bytes.append(contentsOf: [UInt8(0xA0 + n)])
        } else if n <= UInt8.max {
          bytes.append(contentsOf: [UInt8(0xB8), UInt8(n)])
        } else if n <= UInt16.max {
          bytes.append(contentsOf: [0xB9] + n.bigEndianBytes(as: UInt16.self))
        } else if n <= UInt32.max {
          bytes.append(contentsOf: [0xBA] + n.bigEndianBytes(as: UInt32.self))
        } else if n <= Int.max {
          bytes.append(contentsOf: [0xBB] + n.bigEndianBytes(as: UInt64.self))
        }

        if sortMapKeysLexicographically {
          var keys: [([UInt8], Int)] = []
          keys.reserveCapacity(n)
          for i in 0..<n {
            let index = i * 2
            let key = a[index]
            let encodedKey: [UInt8]
            if case .literal(let data) = key {
              encodedKey = data
            } else {
              encodedKey = writeValue(key)
            }
            keys.append((encodedKey, index))
          }
          keys.sort { $0.0.lexicographicallyPrecedes($1.0) }

          for (encodedKey, index) in keys {
            bytes.append(contentsOf: encodedKey)
            writeValue(a[index + 1], into: &bytes)
          }
        } else {
          for i in 0..<n {
            let key = a[i * 2]
            let value = a[i * 2 + 1]
            writeValue(key, into: &bytes)
            writeValue(value, into: &bytes)
          }
        }
      default:
        break
      }
    }
  }
}

enum CborOpCode {
  case uint(UInt8)
  case nint(UInt8)
  case bin(UInt8)
  case str(UInt8)
  case tagged(UInt8)
  case float(UInt8)
  case array(UInt8)
  case map(UInt8)
  case end

  init(ch c: UInt8) {
    let majorType: UInt8 = (c & 0b1110_0000) >> 5
    let additional: UInt8 = c & 0b0001_1111
    switch majorType {
    case 0:
      self = .uint(additional)
    case 1:
      self = .nint(additional)
    case 2:
      self = .bin(additional)
    case 3:
      self = .str(additional)
    case 4:
      self = .array(additional)
    case 5:
      self = .map(additional)
    case 6:
      self = .tagged(additional)
    case 7:
      self = .float(additional)
    default:
      fatalError()
    }
  }
}
