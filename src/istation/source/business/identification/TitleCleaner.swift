import Foundation

public enum TitleCleaner {
    /// "Final Fantasy VII (USA) (Disc 1) [!].cue" → "Final Fantasy VII"
    public static func clean(_ fileName: String) -> String {
        var name = (fileName as NSString).deletingPathExtension
        name = name.replacingOccurrences(of: #"\s*[\(\[][^\)\]]*[\)\]]"#, with: "", options: .regularExpression)
        name = name.replacingOccurrences(of: "_", with: " ")
        name = name.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? (fileName as NSString).deletingPathExtension : trimmed
    }
}
