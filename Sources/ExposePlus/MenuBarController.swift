import AppKit
import ExposePlusCore
import ServiceManagement

final class MenuBarController: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private lazy var settingsWindow = SettingsWindowController()

    override init() {
        super.init()
        item.button?.image = Self.menuBarImage()
        menu.delegate = self
        item.menu = menu
        rebuild()
    }

    private static func menuBarImage() -> NSImage? {
        if let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            if let url2x = Bundle.main.url(forResource: "MenuBarIcon@2x", withExtension: "png"),
               let rep = NSImageRep(contentsOf: url2x) { img.addRepresentation(rep) }
            img.size = NSSize(width: 18, height: 18)
            img.isTemplate = true
            img.accessibilityDescription = "Expose Plus"
            return img
        }
        return NSImage(systemSymbolName: "rectangle.3.group", accessibilityDescription: "Expose Plus")
    }

    func menuNeedsUpdate(_ menu: NSMenu) { rebuild() }

    private func rebuild() {
        menu.removeAllItems()
        if !AXIsProcessTrusted() {
            let warn = NSMenuItem(title: "⚠️ Enable Accessibility…", action: #selector(openAccessibility), keyEquivalent: "")
            warn.target = self
            menu.addItem(warn)
            menu.addItem(.separator())
        }
        let settings = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        let login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())
        let about = NSMenuItem(title: "About Expose Plus…", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        let log = NSMenuItem(title: "Show Log", action: #selector(showLog), keyEquivalent: "")
        log.target = self
        menu.addItem(log)
        menu.addItem(NSMenuItem(title: "Quit Expose Plus", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    @objc private func showSettings() { settingsWindow.show() }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
        } catch {
            let alert = NSAlert(error: error)
            alert.informativeText = "Launch at login only works when running the built ExposePlus.app."
            alert.runModal()
        }
    }

    @objc private func showAbout() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        let center = NSMutableParagraphStyle()
        center.alignment = .center
        let text: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor, .paragraphStyle: center]
        let credits = NSMutableAttributedString(
            string: "\(AboutInfo.tagline)\n\nCreated by \(AboutInfo.creator)\n\n\(AboutInfo.donationPrompt)\n",
            attributes: text)
        credits.append(NSAttributedString(string: AboutInfo.donationLinkText, attributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium), .paragraphStyle: center,
            .link: AboutInfo.donationURL, .foregroundColor: NSColor.linkColor]))
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Expose Plus",
            .applicationVersion: version,
            .version: build,
            .credits: credits,
        ])
    }

    @objc private func showLog() { NSWorkspace.shared.open(Log.url) }

    @objc private func openAccessibility() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
}
