import Compression
import Foundation

/// The single-file form of a style pack: a `.maccursorstyle` file, which is a plain zip
/// holding `style.json` and the art file, at the root or inside one top-level folder.
///
/// Reading is done here, not with `unzip` or `ditto`: only the two expected files are taken,
/// into memory, with limits checked before and while inflating. So a hostile file can't write
/// anywhere, can't hide a link, and can't expand without bound. Only *stored* and *deflate*
/// entries are supported, which is what every zip tool writes by default.
public enum PackArchive {
    public static let fileExtension = "maccursorstyle"
    public static let maxArchiveBytes = 2 * 1024 * 1024
    public static let maxEntries = 32

    /// Reads a pack file into its files' contents, keyed by file name (no folder).
    public static func read(_ data: Data) -> Result<[String: Data], PackProblem> {
        do {
            return .success(try Reader(data).files())
        } catch let p as PackProblem {
            return .failure(p)
        } catch {
            return .failure(problem("can't be read: \(error)"))
        }
    }

    /// Loads a pack file: reads it, then validates it like a folder.
    public static func load(_ data: Data) -> PackLoad {
        switch read(data) {
        case .success(let files): return StylePackLoader.load(files: files)
        case .failure(let p): return PackLoad(pack: nil, problems: [p], warnings: [])
        }
    }

    /// Writes a pack file holding `files` at its root. The same input always gives the same
    /// bytes (sorted names, fixed timestamps), so the gallery can compare SHA-256s.
    public static func write(files: [String: Data]) -> Data {
        var out = Data()
        var central = Data()
        let names = files.keys.sorted { a, b in
            // style.json first, so tools that peek at the start find the manifest.
            a == Manifest.file ? true : b == Manifest.file ? false : a < b
        }
        for name in names {
            guard let content = files[name] else { continue }
            let nameBytes = Data(name.utf8)
            let crc = CRC32.checksum(content)
            let deflated = deflate(content)
            // Keep deflate only when it helps.
            let (method, body): (UInt16, Data) =
                deflated.map { $0.count < content.count ? (8, $0) : (0, content) } ?? (0, content)
            let offset = UInt32(out.count)
            // Local file header.
            out.append(le32: 0x0403_4b50)
            out.append(le16: 20)  // version needed: 2.0
            out.append(le16: 0x0800)  // UTF-8 names
            out.append(le16: method)
            out.append(le16: 0)  // time 00:00
            out.append(le16: 0x0021)  // date 1980-01-01
            out.append(le32: crc)
            out.append(le32: UInt32(body.count))
            out.append(le32: UInt32(content.count))
            out.append(le16: UInt16(nameBytes.count))
            out.append(le16: 0)
            out.append(nameBytes)
            out.append(body)
            // Central directory entry.
            central.append(le32: 0x0201_4b50)
            central.append(le16: 0x0314)  // made by: Unix, 2.0
            central.append(le16: 20)
            central.append(le16: 0x0800)
            central.append(le16: method)
            central.append(le16: 0)
            central.append(le16: 0x0021)
            central.append(le32: crc)
            central.append(le32: UInt32(body.count))
            central.append(le32: UInt32(content.count))
            central.append(le16: UInt16(nameBytes.count))
            central.append(le16: 0)  // extra
            central.append(le16: 0)  // comment
            central.append(le16: 0)  // disk
            central.append(le16: 0)  // internal attributes
            central.append(le32: UInt32(0o100644) << 16)  // regular file, rw-r--r--
            central.append(le32: offset)
            central.append(nameBytes)
        }
        let centralOffset = UInt32(out.count)
        out.append(central)
        out.append(le32: 0x0605_4b50)
        out.append(le16: 0)
        out.append(le16: 0)
        out.append(le16: UInt16(names.count))
        out.append(le16: UInt16(names.count))
        out.append(le32: UInt32(central.count))
        out.append(le32: centralOffset)
        out.append(le16: 0)
        return out
    }

    static func problem(_ message: String) -> PackProblem { PackProblem(file: "", message) }

    // MARK: Reading

    private struct Entry {
        let name: String
        let method: UInt16
        let crc: UInt32
        let compressedSize: Int
        let size: Int
        let localOffset: Int
    }

    private struct Reader {
        let data: Data

        init(_ data: Data) { self.data = Data(data) }  // zero-based indices

        func files() throws -> [String: Data] {
            guard data.count <= maxArchiveBytes else {
                throw problem("is larger than 2 MB; a style pack file should be well under that")
            }
            let entries = try centralDirectory()
            // Files we might want: skip folders, Finder's __MACOSX and hidden files.
            let kept = entries.filter { e in
                let parts = e.name.split(separator: "/", omittingEmptySubsequences: false)
                return !e.name.hasSuffix("/") && parts.first != "__MACOSX"
                    && !parts.contains { $0.hasPrefix(".") }
            }
            // The pack's files sit at the root or in one top-level folder.
            let prefix: String
            if kept.contains(where: { $0.name == Manifest.file }) {
                prefix = ""
            } else {
                let tops = Set(
                    kept.compactMap { e -> String? in
                        let parts = e.name.split(separator: "/")
                        return parts.count == 2 && parts[1] == Manifest.file
                            ? String(parts[0]) : nil
                    })
                guard tops.count == 1, let top = tops.first else {
                    throw problem(
                        tops.isEmpty
                            ? "has no style.json at its top level"
                            : "holds more than one pack folder; put one pack in each file")
                }
                prefix = top + "/"
            }
            func entry(_ name: String) -> Entry? { kept.first { $0.name == prefix + name } }

            var files: [String: Data] = [:]
            guard let manifest = entry(Manifest.file) else {
                throw problem("has no style.json at its top level")
            }
            files[Manifest.file] = try extract(manifest, limit: Manifest.maxBytes)
            let art = StylePackLoader.artFileName(files[Manifest.file] ?? Data()) ?? SVGArt.file
            if StylePackLoader.isPlainFileName(art), let e = entry(art) {
                files[art] = try extract(e, limit: StylePackLoader.maxArtBytes)
            }
            return files
        }

        private func centralDirectory() throws -> [Entry] {
            // The end record is in the last 22 bytes plus a comment of up to 64 KB.
            let notZip = problem("isn't a style pack file (not a zip archive)")
            guard data.count >= 22 else { throw notZip }
            var eocd: Int?
            var i = data.count - 22
            let floor = max(0, data.count - 22 - 0xFFFF)
            while i >= floor {
                if u32(i) == 0x0605_4b50 {
                    eocd = i
                    break
                }
                i -= 1
            }
            guard let e = eocd else { throw notZip }
            let disk = u16(e + 4)
            let cdDisk = u16(e + 6)
            let onDisk = Int(u16(e + 8))
            let total = Int(u16(e + 10))
            let cdSize = Int(u32(e + 12))
            let cdOffset = Int(u32(e + 16))
            if disk != 0 || cdDisk != 0 || onDisk != total {
                throw problem("is a multi-part zip, which isn't supported")
            }
            if total == 0xFFFF || cdSize == 0xFFFF_FFFF || cdOffset == 0xFFFF_FFFF {
                throw problem("is a zip64 archive, which isn't supported")
            }
            guard total <= maxEntries else {
                throw problem("holds \(total) files; a style pack has at most \(maxEntries)")
            }
            guard cdOffset + cdSize <= e else { throw problem("is damaged (bad directory)") }

            var entries: [Entry] = []
            var p = cdOffset
            for _ in 0..<total {
                guard p + 46 <= e, u32(p) == 0x0201_4b50 else {
                    throw problem("is damaged (bad directory entry)")
                }
                let madeBy = u16(p + 4)
                let flags = u16(p + 8)
                let method = u16(p + 10)
                let crc = u32(p + 16)
                let csize = Int(u32(p + 20))
                let size = Int(u32(p + 24))
                let nameLen = Int(u16(p + 28))
                let extraLen = Int(u16(p + 30))
                let commentLen = Int(u16(p + 32))
                let external = u32(p + 38)
                let local = Int(u32(p + 42))
                guard p + 46 + nameLen <= e,
                    let name = String(data: data[(p + 46)..<(p + 46 + nameLen)], encoding: .utf8)
                else {
                    throw problem("is damaged (bad file name)")
                }
                if flags & 1 != 0 { throw problem("is encrypted, which isn't supported") }
                if csize == 0xFFFF_FFFF || size == 0xFFFF_FFFF || local == 0xFFFF_FFFF {
                    throw problem("is a zip64 archive, which isn't supported")
                }
                let parts = name.split(separator: "/", omittingEmptySubsequences: false)
                if name.hasPrefix("/") || name.contains("\\") || parts.contains("..") {
                    throw problem("contains an unsafe path (\(name))")
                }
                // Unix mode in the high bits; links are refused outright.
                if madeBy >> 8 == 3, (external >> 16) & 0o170000 == 0o120000 {
                    throw problem("contains a link (\(name)); packs must hold plain files")
                }
                entries.append(
                    Entry(
                        name: name, method: method, crc: crc, compressedSize: csize, size: size,
                        localOffset: local))
                p += 46 + nameLen + extraLen + commentLen
            }
            return entries
        }

        private func extract(_ e: Entry, limit: Int) throws -> Data {
            let name = (e.name as NSString).lastPathComponent
            guard e.size <= limit else {
                throw PackProblem(file: name, "is larger than \(limit / 1024) KB")
            }
            let lh = e.localOffset
            guard lh + 30 <= data.count, u32(lh) == 0x0403_4b50 else {
                throw problem("is damaged (bad entry for \(e.name))")
            }
            let start = lh + 30 + Int(u16(lh + 26)) + Int(u16(lh + 28))
            guard start + e.compressedSize <= data.count else {
                throw problem("is damaged (\(e.name) is cut short)")
            }
            let body = data[start..<(start + e.compressedSize)]
            let out: Data
            switch e.method {
            case 0:
                out = Data(body)
            case 8:
                guard let inflated = PackArchive.inflate(body, limit: limit) else {
                    throw PackProblem(
                        file: name, "is damaged or larger than \(limit / 1024) KB when unpacked")
                }
                out = inflated
            default:
                throw problem(
                    "uses a compression method (\(e.method)) that isn't supported; use standard zip"
                )
            }
            guard out.count == e.size, CRC32.checksum(out) == e.crc else {
                throw problem("is damaged (\(e.name) doesn't match its checksum)")
            }
            return out
        }

        private func u16(_ i: Int) -> UInt16 {
            UInt16(data[data.startIndex + i]) | UInt16(data[data.startIndex + i + 1]) << 8
        }

        private func u32(_ i: Int) -> UInt32 {
            UInt32(u16(i)) | UInt32(u16(i + 2)) << 16
        }
    }

    // MARK: Deflate

    /// Inflates raw deflate data, stopping (and returning nil) past `limit` bytes of output.
    static func inflate(_ input: Data, limit: Int) -> Data? {
        process(input, operation: COMPRESSION_STREAM_DECODE, limit: limit)
    }

    static func deflate(_ input: Data) -> Data? {
        process(input, operation: COMPRESSION_STREAM_ENCODE, limit: input.count * 2 + 1024)
    }

    private static func process(
        _ input: Data, operation: compression_stream_operation, limit: Int
    ) -> Data? {
        let chunk = 64 * 1024
        let dst = UnsafeMutablePointer<UInt8>.allocate(capacity: chunk)
        defer { dst.deallocate() }
        var stream = compression_stream(
            dst_ptr: dst, dst_size: 0, src_ptr: dst, src_size: 0, state: nil)
        guard compression_stream_init(&stream, operation, COMPRESSION_ZLIB) == COMPRESSION_STATUS_OK
        else { return nil }
        defer { compression_stream_destroy(&stream) }

        var output = Data()
        let ok: Bool = input.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> Bool in
            guard let base = raw.bindMemory(to: UInt8.self).baseAddress else {
                return operation == COMPRESSION_STREAM_ENCODE
            }
            stream.src_ptr = base
            stream.src_size = raw.count
            while true {
                stream.dst_ptr = dst
                stream.dst_size = chunk
                let flags =
                    operation == COMPRESSION_STREAM_ENCODE
                    ? Int32(COMPRESSION_STREAM_FINALIZE.rawValue) : 0
                let status = compression_stream_process(&stream, flags)
                let produced = chunk - stream.dst_size
                if output.count + produced > limit { return false }
                output.append(dst, count: produced)
                switch status {
                case COMPRESSION_STATUS_END: return true
                case COMPRESSION_STATUS_OK:
                    // Decoding ran out of input without reaching the end: truncated data.
                    if stream.src_size == 0 && produced == 0 { return false }
                default: return false
                }
            }
        }
        if input.isEmpty && operation == COMPRESSION_STREAM_DECODE { return nil }
        return ok ? output : nil
    }
}

/// CRC-32 (IEEE), as zip uses.
enum CRC32 {
    private static let table: [UInt32] = (0..<256).map { n in
        var c = UInt32(n)
        for _ in 0..<8 { c = c & 1 != 0 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1 }
        return c
    }

    static func checksum(_ data: Data) -> UInt32 {
        var c: UInt32 = 0xFFFF_FFFF
        for b in data { c = table[Int((c ^ UInt32(b)) & 0xFF)] ^ (c >> 8) }
        return c ^ 0xFFFF_FFFF
    }
}

extension Data {
    fileprivate mutating func append(le16 v: UInt16) {
        append(UInt8(v & 0xFF))
        append(UInt8(v >> 8))
    }

    fileprivate mutating func append(le32 v: UInt32) {
        append(le16: UInt16(v & 0xFFFF))
        append(le16: UInt16(v >> 16))
    }
}
