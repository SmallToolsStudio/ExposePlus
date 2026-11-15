import Foundation

/// Text and links shown in the About window.
public enum AboutInfo {
    public static let creator = "Small Tools Studio"
    public static let tagline = "Keyboard shortcuts for macOS Mission Control."
    /// Plain lead-in, followed by the hyperlinked `donationLinkText`.
    public static let donationPrompt = "Enjoying Expose Plus?"
    /// The clickable phrase (a hyperlink to `donationURL`; the raw URL is never shown).
    public static let donationLinkText = "Support \(creator) with a coffee ☕"
    public static let donationURL = URL(string: "https://ko-fi.com/smalltoolsstudio")!
}
