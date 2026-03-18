import AppKit
import CryptoKit
import Darwin
import Foundation
import Security

// MARK: - Argon2 parameters (UserDefaults-backed)

enum Argon2Params {
    /// Clamps memoryKiB, iterations, parallelism to valid RFC 9106 ranges. Defaults to 65535, 3, 1 when invalid.
    nonisolated static func sanitized(memoryKiB: Int, iterations: Int, parallelism: Int) -> (memoryKiB: Int, iterations: Int, parallelism: Int) {
        let p = max(1, parallelism)
        let t = max(1, iterations)
        let minM = max(8, 8 * p)
        let m = memoryKiB >= minM ? memoryKiB : 65535
        return (m, t, p)
    }
}

// MARK: - Feedback sounds (UserDefaults-backed)

@MainActor
enum ClipboardSound {
    private static let writtenSoundKey  = "clipboardWrittenSound"
    private static let writtenVolumeKey = "clipboardWrittenVolume"
    private static let errorSoundKey    = "clipboardErrorSound"
    private static let errorVolumeKey   = "clipboardErrorVolume"

    private static func currentWrittenSoundName() -> String {
        UserDefaults.standard.string(forKey: writtenSoundKey) ?? "Frog"
    }

    private static func currentErrorSoundName() -> String {
        UserDefaults.standard.string(forKey: errorSoundKey) ?? "Beep"
    }

    private static func currentWrittenVolume() -> Int {
        let v = UserDefaults.standard.object(forKey: writtenVolumeKey) as? Int ?? 50
        return max(0, min(100, v))
    }

    private static func currentErrorVolume() -> Int {
        let v = UserDefaults.standard.object(forKey: errorVolumeKey) as? Int ?? 50
        return max(0, min(100, v))
    }

    private static func playSound(named soundName: String, volume: Int, muted: Bool) {
        guard !muted, volume > 0 else { return }
        guard let snd = NSSound(named: soundName) else { return }
        snd.volume = Float(volume) / 100.0
        snd.play()
    }

    static func playClipboardWritten(muted: Bool) {
        playSound(named: currentWrittenSoundName(), volume: currentWrittenVolume(), muted: muted)
    }

    static func playClipboardError(muted: Bool) {
        playSound(named: currentErrorSoundName(), volume: currentErrorVolume(), muted: muted)
    }
}

// MARK: - Clipboard read/write

@MainActor
enum ClipboardIO {
    static func readString() -> String? {
        NSPasteboard.general.string(forType: .string)
    }

    @discardableResult
    static func writeString(_ string: String) -> Bool {
        NSPasteboard.general.clearContents()
        return NSPasteboard.general.setString(string, forType: .string)
    }
}

// MARK: - Transform clipboard (read → transform → write)

@MainActor
enum ClipboardTransform {
    struct TransformError: LocalizedError, CustomStringConvertible {
        let description: String
        var errorDescription: String? { description }
    }

    /// Read clipboard, apply transform, write back. Plays success or error sound.
    @discardableResult
    static func apply(_ transform: (String) -> String, muted: Bool) -> Bool {
        guard let str = ClipboardIO.readString() else {
            ClipboardSound.playClipboardError(muted: muted)
            return false
        }
        let result = transform(str)
        guard ClipboardIO.writeString(result) else {
            ClipboardSound.playClipboardError(muted: muted)
            return false
        }
        ClipboardSound.playClipboardWritten(muted: muted)
        return true
    }

    /// Like apply, but transform returns nil on failure (e.g. invalid URL). On nil, beeps and does not write.
    @discardableResult
    static func applyIfValid(_ transform: (String) -> String?, muted: Bool) -> Bool {
        guard let str = ClipboardIO.readString() else {
            ClipboardSound.playClipboardError(muted: muted)
            return false
        }
        guard let result = transform(str) else {
            ClipboardSound.playClipboardError(muted: muted)
            return false
        }
        guard ClipboardIO.writeString(result) else {
            ClipboardSound.playClipboardError(muted: muted)
            return false
        }
        ClipboardSound.playClipboardWritten(muted: muted)
        return true
    }

    /// Like applyIfValid, but captures typed transform errors so DEBUG builds can log the exact reason.
    @discardableResult
    static func applyIfValid(_ transform: (String) throws -> String, muted: Bool) -> Bool {
        guard let str = ClipboardIO.readString() else {
            ClipboardSound.playClipboardError(muted: muted)
            return false
        }
        do {
            let result = try transform(str)
            guard ClipboardIO.writeString(result) else {
                ClipboardSound.playClipboardError(muted: muted)
                return false
            }
            ClipboardSound.playClipboardWritten(muted: muted)
            return true
        } catch {
            #if DEBUG
            print("[ClipboardTransform] \(error)")
            #endif
            ClipboardSound.playClipboardError(muted: muted)
            return false
        }
    }

}

// MARK: - Set clipboard to generated values (dates, UUID)

@MainActor
enum ClipboardSet {
    static func setAndNotify(_ value: String, muted: Bool) {
        guard ClipboardIO.writeString(value) else { return }
        ClipboardSound.playClipboardWritten(muted: muted)
    }

    static func epochSeconds() -> String { TimeOutput.epochSeconds(from: Date()) }
    static func epochMilliseconds() -> String { TimeOutput.epochMilliseconds(from: Date()) }
    static func sqlDateTimeLocal() -> String { TimeOutput.sqlDateTimeLocal(from: Date()) }
    static func sqlDateTimeUTC() -> String { TimeOutput.sqlDateTimeUTC(from: Date()) }
    static func rfc3339Z() -> String { TimeOutput.rfc3339Z(from: Date()) }
    static func rfc3339WithOffset() -> String { TimeOutput.rfc3339WithOffset(from: Date()) }
    static func rfc3339WithAbbreviation() -> String { TimeOutput.rfc3339WithAbbreviation(from: Date()) }
    static func rfc1123Local() -> String { TimeOutput.rfc1123Local(from: Date()) }
    static func rfc1123UTC() -> String { TimeOutput.rfc1123UTC(from: Date()) }
    static func yyyyMMddHHmmssLocal() -> String { TimeOutput.yyyyMMddHHmmssLocal(from: Date()) }
    static func yyyyMMddHHmmssUTC() -> String { TimeOutput.yyyyMMddHHmmssUTC(from: Date()) }
    static func yyMMddHHmmssLocal() -> String { TimeOutput.yyMMddHHmmssLocal(from: Date()) }
    static func yyMMddHHmmssUTC() -> String { TimeOutput.yyMMddHHmmssUTC(from: Date()) }
    static func yyyyMMddLocal() -> String { TimeOutput.yyyyMMddLocal(from: Date()) }
    static func yyyyMMddUTC() -> String { TimeOutput.yyyyMMddUTC(from: Date()) }
    static func yyyyMMddHHLocal() -> String { TimeOutput.yyyyMMddHHLocal(from: Date()) }
    static func yyyyMMddHHUTC() -> String { TimeOutput.yyyyMMddHHUTC(from: Date()) }
    static func yyMMddLocal() -> String { TimeOutput.yyMMddLocal(from: Date()) }
    static func yyMMddUTC() -> String { TimeOutput.yyMMddUTC(from: Date()) }

    static func randomUUID() -> String { UUID().uuidString }
    static func randomUUIDLowercase() -> String { UUID().uuidString.lowercased() }

    // MARK: - Secure random helpers

    private static func secureRandomBytes(count: Int) -> Data? {
        var data = Data(count: count)
        let success = data.withUnsafeMutableBytes { ptr in
            guard let base = ptr.baseAddress else { return false }
            return SecRandomCopyBytes(kSecRandomDefault, count, base) == errSecSuccess
        }
        return success ? data : nil
    }

    /// 32 hex chars (16 bytes) or 64 hex chars (32 bytes).
    static func randomHexString(byteCount: Int) -> String? {
        guard let data = secureRandomBytes(count: byteCount) else { return nil }
        return data.map { String(format: "%02x", $0) }.joined()
    }

    /// ULID: 26 chars, Crockford base32, 48-bit timestamp + 80-bit random.
    private static let ulidAlphabet = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")

    static func randomULID() -> String? {
        let ms = UInt64(Date().timeIntervalSince1970 * 1000)
        guard let randomPart = secureRandomBytes(count: 10) else { return nil }
        var bytes: [UInt8] = []
        bytes.append(UInt8((ms >> 40) & 0xFF))
        bytes.append(UInt8((ms >> 32) & 0xFF))
        bytes.append(UInt8((ms >> 24) & 0xFF))
        bytes.append(UInt8((ms >> 16) & 0xFF))
        bytes.append(UInt8((ms >> 8) & 0xFF))
        bytes.append(UInt8(ms & 0xFF))
        bytes.append(contentsOf: randomPart)
        // Encode 16 bytes = 128 bits as 26 base32 chars (5 bits per char; last char = 3 data bits + 2 zero padding)
        var result = ""
        var bitBuffer = 0
        var bitCount = 0
        for b in bytes {
            bitBuffer = (bitBuffer << 8) | Int(b)
            bitCount += 8
            while bitCount >= 5 {
                let shift = bitCount - 5
                result.append(ulidAlphabet[(bitBuffer >> shift) & 0x1F])
                bitBuffer &= (1 << shift) - 1
                bitCount = shift
            }
        }
        if bitCount > 0 {
            result.append(ulidAlphabet[(bitBuffer << (5 - bitCount)) & 0x1F])
        }
        return result.count == 26 ? result : nil
    }

    /// NanoID: URL-safe alphanumeric, default 21 chars.
    private static let nanoidAlphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")

    static func randomNanoID(length: Int = 21) -> String? {
        guard let data = secureRandomBytes(count: length) else { return nil }
        return data.map { nanoidAlphabet[Int($0) % nanoidAlphabet.count] }.map(String.init).joined()
    }

    /// Very complex: 20 chars from upper, lower, digits, and symbols.
    static func randomVeryComplexPassword(length: Int = 20) -> String? {
        let upper = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        let lower = Array("abcdefghijklmnopqrstuvwxyz")
        let digits = Array("0123456789")
        let symbols = Array("!@#$%^&*()_+-=[]{}|;:,.<>?")
        let all = upper + lower + digits + symbols
        guard let data = secureRandomBytes(count: length), data.count >= 4 else { return nil }
        var chars = data.map { all[Int($0) % all.count] }
        chars[0] = upper[Int(data[0]) % upper.count]
        chars[1] = lower[Int(data[1]) % lower.count]
        chars[2] = digits[Int(data[2]) % digits.count]
        chars[3] = symbols[Int(data[3]) % symbols.count]
        return String(chars)
    }

    /// Complex: 20 lowercase alphanumeric in groups of 5 with hyphens (e.g. or2at-23adr-2jASe9-cacTr3 -> 5-5-5-5).
    static func randomComplexPassword(length: Int = 20) -> String? {
        let alphabet = Array("abcdefghijklmnopqrstuvwxyz0123456789")
        guard let data = secureRandomBytes(count: length) else { return nil }
        let chars = data.map { alphabet[Int($0) % alphabet.count] }
        let s = String(chars)
        let g = 5
        return stride(from: 0, to: s.count, by: g).map { i in String(s[s.index(s.startIndex, offsetBy: i)..<s.index(s.startIndex, offsetBy: min(i + g, s.count))]) }.joined(separator: "-")
    }

    /// Alphanumeric: 20 chars, mixed case + digits.
    static func randomAlphanumericPassword(length: Int = 20) -> String? {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
        guard let data = secureRandomBytes(count: length) else { return nil }
        return String(data.map { alphabet[Int($0) % alphabet.count] })
    }

    static let loremIpsumPlaceholderShort = "Lorem ipsum dolor sit amet, consectetur adipiscing elit."
    static let loremIpsumPlaceholderMedium = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat."
    static let loremIpsumPlaceholderFull = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Mauris nec tortor eget mi eleifend tristique. Proin a faucibus arcu, ac suscipit turpis. Sed luctus sagittis nunc, cursus viverra risus rhoncus lobortis. Donec commodo imperdiet hendrerit. Maecenas egestas tristique erat nec condimentum. Donec eget congue magna, at pulvinar enim. Donec convallis mauris libero, vulputate fermentum elit pulvinar a.\n\nVestibulum dolor ipsum, gravida ac cursus ac, venenatis vitae ex. Morbi suscipit pellentesque erat, a interdum felis. Ut a molestie neque. Phasellus euismod nulla sed nisl dignissim lacinia. Donec sit amet sagittis dolor, id blandit est. Vivamus mollis pulvinar felis, sed laoreet lorem ornare eget. Curabitur nec gravida lacus, non feugiat sem. Nunc dapibus porttitor erat quis accumsan. Fusce aliquet ultricies ante, sed facilisis lectus efficitur eu. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos himenaeos. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia curae; Ut pretium nisi id tristique porta.\n\nDuis eu accumsan mauris. Praesent et ex vulputate, imperdiet diam sit amet, auctor nibh. In felis ex, accumsan vitae rutrum sed, congue vitae metus. Nam dictum fringilla hendrerit. Integer finibus eget felis in iaculis. Nam ac tortor in nunc tincidunt pharetra ut at enim. Phasellus in vulputate orci. Cras hendrerit faucibus arcu, id sodales leo luctus ac. Cras accumsan diam semper lacus consequat vehicula. In vel euismod felis, at cursus est. Morbi feugiat viverra porta. Aenean sit amet lectus sit amet ipsum iaculis luctus ut vulputate erat. Aliquam imperdiet accumsan ipsum sed laoreet. Mauris et augue mollis, scelerisque urna id, porta orci. Interdum et malesuada fames ac ante ipsum primis in faucibus. Etiam pellentesque, tortor at elementum feugiat, metus lacus pharetra nisi, eu rutrum est ipsum sit amet magna.\n\nMorbi lacinia nisi vel tempor feugiat. Integer orci nisi, gravida sit amet interdum quis, blandit et neque. Ut eleifend rutrum mi. Vestibulum metus odio, fringilla et commodo sed, ultrices nec elit. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Pellentesque tempus facilisis quam, ut dignissim lectus blandit in. Etiam metus mauris, feugiat a nisl in, elementum lobortis dolor. Nulla facilisi. Vivamus fermentum feugiat lacus. Mauris sit amet felis ligula. Etiam malesuada, nulla quis sollicitudin egestas, lorem lacus ullamcorper diam, non varius massa lacus vel erat. Fusce eleifend rutrum dolor, sed maximus urna ornare sit amet. Vestibulum ut ex mattis lectus pellentesque convallis at et lectus.\n\nDuis sit amet consequat diam. Proin eu vulputate mauris. Nam tincidunt dictum fringilla. Duis ut pellentesque orci. Vivamus vestibulum pharetra pharetra. Quisque viverra pellentesque risus, tempus finibus erat maximus sit amet. Nullam consequat venenatis turpis sed dapibus. Pellentesque aliquam vel felis et gravida. Fusce faucibus, tellus ac malesuada dignissim, metus urna aliquet lacus, ac lobortis nisl dolor egestas nunc. Praesent magna nisl, gravida vel imperdiet sit amet, eleifend vitae dolor. Suspendisse sit amet turpis ultricies, aliquam leo eget, egestas magna. Vivamus non congue ante."

    static let quickBrownFoxPlaceholder = "The quick brown fox jumps over the lazy dog"
    static let packMyBoxPlaceholder = "Pack my box with five dozen liquor jugs."
    static let sphinxOfBlackQuartzPlaceholder = "Sphinx of black quartz, judge my vow."
    static let waltzBadNymphPlaceholder = "Waltz, bad nymph, for quick jigs vex!"
    static let jackdawsPlaceholder = "Jackdaws love my big sphinx of quartz."
}
