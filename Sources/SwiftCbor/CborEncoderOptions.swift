extension CborEncoder {
  public struct Options: OptionSet, Sendable {
    public let rawValue: UInt16

    public init(rawValue: UInt16) {
      self.rawValue = rawValue
    }

    public static let lexicographicallySortedMapKeys = Options(rawValue: 1 << 0)
    public static let shortestFloatingPointEncoding = Options(rawValue: 1 << 1)
    public static let finiteFloatingPointValuesOnly = Options(rawValue: 1 << 2)
    public static let floatingPoint64Only = Options(rawValue: 1 << 3)

    var hasConflictingFloatingPointOptions: Bool {
      contains(.shortestFloatingPointEncoding) && contains(.floatingPoint64Only)
    }

    /// Applies the core deterministic encoding requirements in RFC 8949 Section 4.2.1.
    ///
    /// This option uses bytewise lexicographic map key ordering, not the length-first ordering in
    /// Section 4.2.3. Signed zero and NaN payloads are preserved. Protocol-specific choices described
    /// in Section 4.2.2 remain the application's responsibility.
    public static let deterministicCbor: Options = [
      .lexicographicallySortedMapKeys,
      .shortestFloatingPointEncoding,
    ]
  }
}
