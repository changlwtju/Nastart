import Foundation

// Simplified Chinese source text is the key, and the host app's en.lproj holds the translation.
// SwiftUI looks up `Text("…")` literals the same way. A host without a table keeps the Chinese.

/// A fixed string, or one with interpolated values, that is not passed straight to a SwiftUI text view.
func networkL(_ key: String.LocalizationValue) -> String { String(localized: key) }

/// Text that arrives as `String` and may be a fixed label or user data such as a folder name.
/// User data has no table entry, so it comes back unchanged.
func networkText(_ text: String) -> String {
    Bundle.main.localizedString(forKey: text, value: text, table: nil)
}

/// Roles are saved in the local index as " · "-joined Chinese labels, so they translate when shown.
func networkRoleText(_ role: String) -> String {
    role.components(separatedBy: " · ").map(networkText).joined(separator: " · ")
}
