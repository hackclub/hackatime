import Foundation

/// What the focused window was doing in a minute. Classified on the device
/// by rules. The title and URL used here never leave the machine; only the
/// label does.
public enum FocusLabel: String, Codable { case project, research, unrelated, unknown }

public struct FocusSample: Equatable {
    public var bundleID: String
    public var appName: String
    public var title: String
    public var url: String?

    public init(bundleID: String, appName: String, title: String, url: String? = nil) {
        self.bundleID = bundleID
        self.appName = appName
        self.title = title
        self.url = url
    }

    public var domain: String? {
        guard let url, let host = URL(string: url)?.host?.lowercased() else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    /// Whether the URL is covered by a domain rule. `x.com` covers x.com and
    /// its subdomains but not dropbox.com; `reddit.com/r/all` also needs the
    /// path; `docs.` covers any host starting with it; a rule with no dot,
    /// such as `bank`, covers any host with it in a label.
    public func matches(_ rule: String) -> Bool {
        guard let domain else { return false }
        if rule.hasSuffix(".") { return domain.hasPrefix(rule) }
        if !rule.contains(".") { return domain.split(separator: ".").contains { $0.contains(rule) } }
        let parts = rule.split(separator: "/", maxSplits: 1)
        let host = String(parts[0])
        guard domain == host || domain.hasSuffix("." + host) else { return false }
        guard parts.count == 2, let url else { return true }
        let path = (URL(string: url)?.path ?? "").lowercased()
        return path == "/" + parts[1] || path.hasPrefix("/" + parts[1] + "/")
    }
}

public struct FocusClassifier {
    /// Never captured and never counted, whatever any other rule says.
    public static let neverBundleIDs: Set<String> = [
        "com.1password.1password", "com.agilebits.onepassword7", "com.bitwarden.desktop", "com.apple.keychainaccess",
        "com.apple.Passwords", "com.lastpass.LastPass", "com.dashlane.dashlanephonefinal",
        "com.apple.MobileSMS", "com.apple.mail", "com.tinyspeck.slackmacgap", "com.hnc.Discord", "net.whatsapp.WhatsApp",
        "ru.keepcoder.Telegram", "org.whispersystems.signal-desktop", "com.microsoft.teams2", "us.zoom.xos",
        "com.facebook.archon", "com.apple.FaceTime", "com.apple.notificationcenterui",
    ]
    public static let neverDomains = [
        "bank", "paypal.com", "stripe.com/dashboard", "venmo.com", "wise.com", "revolut.com", "monzo.com",
        "mail.google.com", "outlook.live.com", "web.whatsapp.com", "messenger.com", "discord.com", "slack.com",
        "accounts.google.com", "appleid.apple.com", "1password.com", "bitwarden.com",
    ]
    static let editorBundleIDs: Set<String> = [
        "com.microsoft.VSCode", "com.todesktop.230313mzl4w4u92", "dev.zed.Zed", "com.apple.dt.Xcode", "com.sublimetext.4",
        "com.jetbrains.intellij", "com.jetbrains.pycharm", "com.jetbrains.WebStorm", "com.jetbrains.goland",
        "com.jetbrains.rubymine", "com.google.android.studio", "com.exafunction.windsurf", "com.panic.Nova",
    ]
    static let terminalBundleIDs: Set<String> = [
        "com.apple.Terminal", "com.googlecode.iterm2", "dev.warp.Warp-Stable", "com.mitchellh.ghostty", "net.kovidgoyal.kitty",
        "io.alacritty", "com.github.wez.wezterm",
    ]
    static let browserBundleIDs: Set<String> = [
        "com.apple.Safari", "com.google.Chrome", "org.mozilla.firefox", "company.thebrowser.Browser", "com.brave.Browser",
        "com.microsoft.edgemac", "com.vivaldi.Vivaldi", "app.zen-browser.zen",
    ]
    static let researchDomains = [
        "developer.apple.com", "developer.mozilla.org", "stackoverflow.com", "stackexchange.com", "docs.", "readthedocs.io",
        "github.com", "gitlab.com", "pkg.go.dev", "crates.io", "docs.rs", "npmjs.com", "pypi.org", "rubygems.org",
        "api.rubyonrails.org", "guides.rubyonrails.org", "svelte.dev", "react.dev", "vuejs.org", "kotlinlang.org",
        "learn.microsoft.com", "w3.org", "caniuse.com", "man7.org", "hackclub.com", "wikipedia.org",
    ]
    static let aiChatDomains = ["chatgpt.com", "claude.ai", "gemini.google.com", "ampcode.com", "perplexity.ai", "v0.dev"]
    static let unrelatedDomains = [
        "youtube.com/shorts", "instagram.com", "tiktok.com", "netflix.com", "twitch.tv", "x.com", "twitter.com",
        "reddit.com/r/all", "facebook.com", "primevideo.com", "disneyplus.com", "store.steampowered.com",
    ]
    static let localHosts = ["localhost", "127.0.0.1", "0.0.0.0", "[::1]"]

    public var projectNames: [String]

    public init(projectNames: [String]) {
        self.projectNames = projectNames.map { $0.lowercased() }
    }

    public static func isNever(_ sample: FocusSample) -> Bool {
        if neverBundleIDs.contains(sample.bundleID) { return true }
        let lowerTitle = sample.title.lowercased()
        if lowerTitle.contains("private browsing") || lowerTitle.contains("incognito") || lowerTitle.contains("inprivate") { return true }
        return neverDomains.contains(where: sample.matches)
    }

    /// Whether a window may be screenshotted at all: never-list loses, then
    /// only editors, terminals, localhost, docs, repos and matched AI chats.
    public func isCaptureAllowed(_ sample: FocusSample, activeProject: String? = nil) -> Bool {
        if Self.isNever(sample) { return false }
        let label = classify(sample, activeProject: activeProject).label
        if label == .project { return true }
        if label == .research {
            return Self.researchDomains.contains(where: sample.matches) || Self.aiChatDomains.contains(where: sample.matches)
        }
        return false
    }

    /// A project name as a whole word: "site" is in "index.html — site" and
    /// "~/code/site/app" but not in "client-website-redesign".
    static func containsName(_ name: String, in text: String) -> Bool {
        let nameChar: (Character) -> Bool = { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
        var start = text.startIndex
        while let range = text.range(of: name, range: start ..< text.endIndex) {
            let before = range.lowerBound == text.startIndex ? nil : text[text.index(before: range.lowerBound)]
            let after = range.upperBound == text.endIndex ? nil : text[range.upperBound]
            if !(before.map(nameChar) ?? false), !(after.map(nameChar) ?? false) { return true }
            start = text.index(after: range.lowerBound)
        }
        return false
    }

    /// `activeProject` is the project the device saw files change in lately.
    /// It names the project of an editor or terminal whose window title is
    /// unknown (no Accessibility permission), so that minute still counts.
    public func classify(_ sample: FocusSample, activeProject: String? = nil) -> (label: FocusLabel, project: String?) {
        if Self.isNever(sample) { return (.unrelated, nil) }
        let haystack = [sample.title, sample.url ?? ""].joined(separator: " ").lowercased()
        let project = projectNames.first { Self.containsName($0, in: haystack) }

        if Self.editorBundleIDs.contains(sample.bundleID) || Self.terminalBundleIDs.contains(sample.bundleID) {
            let project = project ?? (sample.title.isEmpty ? activeProject?.lowercased() : nil)
            return (project == nil ? .unknown : .project, project)
        }
        if Self.browserBundleIDs.contains(sample.bundleID), let domain = sample.domain {
            if Self.localHosts.contains(domain) { return (.project, project) }
            if Self.unrelatedDomains.contains(where: sample.matches) { return (.unrelated, nil) }
            if Self.aiChatDomains.contains(where: sample.matches) { return (.research, project) }
            if Self.researchDomains.contains(where: sample.matches) {
                return (project != nil && sample.matches("github.com") ? .project : .research, project)
            }
        }
        if let project, sample.bundleID == "com.apple.Preview" || sample.bundleID.hasPrefix("com.figma") {
            return (.project, project)
        }
        return (.unknown, project)
    }
}
