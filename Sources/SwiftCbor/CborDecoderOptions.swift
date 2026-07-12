extension CborDecoder {
  public struct Options: OptionSet, Sendable {
    public let rawValue: UInt16

    public init(rawValue: UInt16) {
      self.rawValue = rawValue
    }

    public static let minimalArgumentEncoding = Options(rawValue: 1 << 0)
    public static let definiteLengthItems = Options(rawValue: 1 << 1)
  }
}
