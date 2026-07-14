extension CborEncoder {
  public struct Options: OptionSet, Sendable {
    public let rawValue: UInt16

    public init(rawValue: UInt16) {
      self.rawValue = rawValue
    }

    public static let lexicographicallySortedMapKeys = Options(rawValue: 1 << 0)
    public static let shortestFloatingPointEncoding = Options(rawValue: 1 << 1)
  }
}
