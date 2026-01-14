import Foundation

/// 将后端的 offset/length 映射到 Swift 字符串范围。
/// 约定：offset/length 以 UTF-16 code unit 为单位（Java String 常见行为）。
enum IssueRangeMapper {
    static func nsRangeFromUTF16Offset(
        _ text: String,
        offset: Int,
        length: Int
    ) -> NSRange? {
        guard offset >= 0, length > 0 else { return nil }

        let utf16 = text.utf16
        let start = utf16.index(utf16.startIndex, offsetBy: offset, limitedBy: utf16.endIndex)
        let end = utf16.index(start ?? utf16.endIndex, offsetBy: length, limitedBy: utf16.endIndex)

        guard let start, let end, start < end else { return nil }

        // NSRange(location:length) 的 location/length 同样是 UTF-16 单位
        let loc = utf16.distance(from: utf16.startIndex, to: start)
        let len = utf16.distance(from: start, to: end)
        return NSRange(location: loc, length: len)
    }
}