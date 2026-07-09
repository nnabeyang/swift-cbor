extension CborDecoder {
  public struct Options: OptionSet, Sendable {
    public let rawValue: UInt16

    public init(rawValue: UInt16) {
      self.rawValue = rawValue
    }

    public static let minimalArgumentEncoding = Options(rawValue: 1 << 0)
    public static let definiteLengthItems = Options(rawValue: 1 << 1)
    public static let lexicographicallySortedMapKeys = Options(rawValue: 1 << 2)
    public static let shortestFloatingPointEncoding = Options(rawValue: 1 << 3)

    /// Validates the core deterministic encoding requirements in RFC 8949 Section 4.2.1.
    ///
    /// This option uses bytewise lexicographic map key ordering, not the length-first ordering in
    /// Section 4.2.3. Protocol-specific choices described in Section 4.2.2, including tag usage,
    /// numeric equivalence, and a single NaN representation, remain the application's responsibility.
    public static let deterministicCbor: Options = [
      .minimalArgumentEncoding,
      .definiteLengthItems,
      .lexicographicallySortedMapKeys,
      .shortestFloatingPointEncoding,
    ]
  }
}
