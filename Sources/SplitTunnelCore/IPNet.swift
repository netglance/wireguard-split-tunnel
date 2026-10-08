import Foundation

/// An IPv4 or IPv6 network in CIDR form. The address is always masked to the prefix.
public struct IPNet: Hashable, Comparable, Sendable, Codable, CustomStringConvertible {
    public let isV6: Bool
    public let address: UInt128
    public let prefix: Int

    var bits: Int { isV6 ? 128 : 32 }

    public init?(_ text: String) {
        let parts = text.trimmingCharacters(in: .whitespaces).split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count <= 2 else { return nil }
        let host = String(parts[0])
        var v4 = in_addr(), v6 = in6_addr()
        let isV6: Bool, value: UInt128
        if inet_pton(AF_INET, host, &v4) == 1 {
            isV6 = false
            value = UInt128(UInt32(bigEndian: v4.s_addr))
        } else if inet_pton(AF_INET6, host, &v6) == 1 {
            isV6 = true
            value = withUnsafeBytes(of: v6) { $0.reduce(UInt128(0)) { $0 << 8 | UInt128($1) } }
        } else {
            return nil
        }
        let maxPrefix = isV6 ? 128 : 32
        var prefix = maxPrefix
        if parts.count == 2 {
            guard parts[1].allSatisfy({ $0.isASCII && $0.isNumber }), let p = Int(parts[1]), (0...maxPrefix).contains(p) else { return nil }
            prefix = p
        }
        self.init(isV6: isV6, address: value, prefix: prefix)
    }

    init(isV6: Bool, address: UInt128, prefix: Int) {
        self.isV6 = isV6
        self.prefix = prefix
        self.address = address & IPNet.mask(prefix: prefix, bits: isV6 ? 128 : 32)
    }

    static func mask(prefix: Int, bits: Int) -> UInt128 {
        guard prefix > 0 else { return 0 }
        let all: UInt128 = bits == 128 ? .max : UInt128(UInt32.max)
        return (all << (bits - prefix)) & all
    }

    public func contains(_ other: IPNet) -> Bool {
        isV6 == other.isV6 && prefix <= other.prefix
            && other.address & IPNet.mask(prefix: prefix, bits: bits) == address
    }

    /// The two subnets one bit longer than this one.
    func halves() -> (IPNet, IPNet) {
        let bit = UInt128(1) << (bits - prefix - 1)
        return (IPNet(isV6: isV6, address: address, prefix: prefix + 1),
                IPNet(isV6: isV6, address: address | bit, prefix: prefix + 1))
    }

    public var addressString: String {
        guard isV6 else {
            let v = UInt32(truncatingIfNeeded: address)
            return "\(v >> 24).\(v >> 16 & 255).\(v >> 8 & 255).\(v & 255)"
        }
        var raw = in6_addr()
        withUnsafeMutableBytes(of: &raw) { bytes in
            for i in 0..<16 { bytes[i] = UInt8(truncatingIfNeeded: address >> (8 * (15 - i))) }
        }
        var out = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
        inet_ntop(AF_INET6, &raw, &out, socklen_t(out.count))
        return out.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
    }

    public var description: String { "\(addressString)/\(prefix)" }

    public static func < (a: IPNet, b: IPNet) -> Bool {
        (a.isV6 ? 1 : 0, a.address, a.prefix) < (b.isV6 ? 1 : 0, b.address, b.prefix)
    }

    public init(from decoder: Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        guard let net = IPNet(text) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Bad CIDR \(text)"))
        }
        self = net
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}
