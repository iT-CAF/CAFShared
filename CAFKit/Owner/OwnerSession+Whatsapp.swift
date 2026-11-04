import Foundation

// The owner's WhatsApp number, inbox and credits (cafbio-mobile: src/Http/WhatsappApi.php). Linking the number (QR) and the bot / flows / campaigns stay on the website.
// Every route answers 404 `module_off` when the module or the plan has no WhatsApp; an answer of `{error:true, code, message}` becomes a CashierError as everywhere else.

/// Link state of the number as the server names it. Unknown words read as `unlinked`, so a new server state never breaks the screen.
enum WhatsAppLinkState: String, Sendable { case connected, disconnected, pending, unlinked }

/// `GET whatsapp/status`. `quota` follows the website: 0 = unlimited, -1 = the plan has no WhatsApp.
struct WhatsAppStatus: Decodable, Equatable, Sendable {
    var linked = false
    var numberMasked = ""
    var state: WhatsAppLinkState = .unlinked
    var serviceReady = true
    var needsRelink = false
    var used = 0, quota = 0, extra = 0
    var manageUrl = "/user/whatsapp"
    /// Where the link QR is. The server currently answers a website path (the scan happens there); a full https image URL would be drawn in place.
    var qrUrl: String?

    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        linked = c.flexBool(.linked) ?? false
        numberMasked = c.string(.numberMasked) ?? ""
        state = (c.string(.state)).flatMap(WhatsAppLinkState.init(rawValue:)) ?? (linked ? .connected : .unlinked)
        serviceReady = c.flexBool(.serviceReady) ?? true
        needsRelink = c.flexBool(.needsRelink) ?? false
        manageUrl = c.string(.manageUrl) ?? "/user/whatsapp"
        qrUrl = c.string(.qrUrl)
        if let k = try? c.nestedContainer(keyedBy: Credits.self, forKey: .credits) { used = k.flexInt(.used) ?? 0; quota = k.flexInt(.quota) ?? 0; extra = k.flexInt(.extra) ?? 0 }
    }
    private enum K: String, CodingKey { case linked, numberMasked, state, serviceReady, needsRelink, credits, manageUrl, qrUrl }
    private enum Credits: String, CodingKey { case used, quota, extra }
}

struct WhatsAppConversation: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    var phoneMasked = ""
    var name = ""
    var last = ""
    /// Direction of the last message: `in` (the customer wrote) or `out`.
    var dir = "in"
    var at: Date?
    var unseen = 0
    var optout = false
    var title: String { name.isEmpty ? phoneMasked : name }

    init(id: String, phoneMasked: String = "", name: String = "", last: String = "", dir: String = "in", at: Date? = nil, unseen: Int = 0, optout: Bool = false) {
        self.id = id; self.phoneMasked = phoneMasked; self.name = name; self.last = last; self.dir = dir; self.at = at; self.unseen = unseen; self.optout = optout
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        id = c.string(.id) ?? ""
        phoneMasked = c.string(.phoneMasked) ?? ""; name = c.string(.name) ?? ""; last = c.string(.last) ?? ""; dir = c.string(.dir) ?? "in"
        at = try? c.decodeIfPresent(Date.self, forKey: .at)
        unseen = c.flexInt(.unseen) ?? 0; optout = c.flexBool(.optout) ?? false
    }
    private enum K: String, CodingKey { case id, phoneMasked, name, last, dir, at, unseen, optout }
}

struct WhatsAppConversationsPage: Decodable, Equatable, Sendable {
    var items: [WhatsAppConversation] = []
    var nextCursor: String?
}

struct WhatsAppMessage: Decodable, Equatable, Identifiable, Sendable {
    let id: Int
    var dir = "in"
    var text = ""
    /// `text` or a media kind the website logged (image, document, …); the body then holds the link or a caption.
    var kind = "text"
    var source = ""
    var ok = true
    var at: Date?
    var isOutgoing: Bool { dir == "out" }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        id = c.flexInt(.id) ?? 0
        dir = c.string(.dir) ?? "in"; text = c.string(.text) ?? ""; kind = c.string(.kind) ?? "text"; source = c.string(.source) ?? ""
        ok = c.flexBool(.ok) ?? true
        at = try? c.decodeIfPresent(Date.self, forKey: .at)
    }
    private enum K: String, CodingKey { case id, dir, text, kind, source, ok, at }
}

struct WhatsAppThreadHead: Decodable, Equatable, Sendable {
    var id = ""
    var phoneMasked = ""
    var name = ""
    var optout = false
    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        id = c.string(.id) ?? ""; phoneMasked = c.string(.phoneMasked) ?? ""; name = c.string(.name) ?? ""; optout = c.flexBool(.optout) ?? false
    }
    private enum K: String, CodingKey { case id, phoneMasked, name, optout }
}

/// Messages come oldest first within a page; `nextCursor` asks for the page before it.
struct WhatsAppThreadPage: Decodable, Equatable, Sendable {
    var conversation = WhatsAppThreadHead()
    var items: [WhatsAppMessage] = []
    var nextCursor: String?
}

/// `GET whatsapp/credits`. `left` and `totalLeft` are nil when the plan is unlimited (`quota == 0`).
struct WhatsAppCredits: Decodable, Equatable, Sendable {
    var quota = 0, used = 0, extra = 0, percent = 0
    var left: Int?
    var totalLeft: Int?
    var resets = ""

    init() {}
    init(from d: Decoder) throws {
        let outer = try d.container(keyedBy: Wrap.self)
        let c = try outer.nestedContainer(keyedBy: K.self, forKey: .credits)
        quota = c.flexInt(.quota) ?? 0; used = c.flexInt(.used) ?? 0; extra = c.flexInt(.extra) ?? 0; percent = c.flexInt(.percent) ?? 0
        left = c.flexInt(.left); totalLeft = c.flexInt(.totalLeft); resets = c.string(.resets) ?? ""
    }
    private enum Wrap: String, CodingKey { case credits }
    private enum K: String, CodingKey { case quota, used, left, extra, totalLeft, percent, resets }
}

struct WhatsAppSendResult: Decodable, Equatable, Sendable {
    var sent = false
    /// The rig answers `dry: true` and sends nothing; the screen then keeps the local copy of the message.
    var dry = false
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        sent = c.flexBool(.sent) ?? false; dry = c.flexBool(.dry) ?? false
    }
    private enum K: String, CodingKey { case sent, dry }
}

extension OwnerSession {
    func whatsappStatus() async throws -> WhatsAppStatus { try decode(WhatsAppStatus.self, try await get("whatsapp/status")) }

    func whatsappConversations(query: String = "", cursor: String? = nil, limit: Int = 30) async throws -> WhatsAppConversationsPage {
        try decode(WhatsAppConversationsPage.self, try await get("whatsapp/conversations" + Self.whatsappQuery(["q": query, "cursor": cursor ?? "", "limit": String(limit)])))
    }

    /// Opening the first page marks the customer's messages as read on the server (as on the website).
    func whatsappThread(id: String, cursor: String? = nil, limit: Int = 50) async throws -> WhatsAppThreadPage {
        try decode(WhatsAppThreadPage.self, try await get("whatsapp/thread" + Self.whatsappQuery(["id": id, "cursor": cursor ?? "", "limit": String(limit)])))
    }

    /// One text message through the website's own sender, so the monthly allowance and purchased credits are charged exactly as there.
    /// Refusals: 403 `plan_limit_reached`, 409 `not_linked`, 429 `rate`, 502 `send_failed`.
    func whatsappSend(to phone: String, text: String) async throws -> WhatsAppSendResult {
        try decode(WhatsAppSendResult.self, try await post("whatsapp/send", ["to": phone, "text": text]))
    }

    func whatsappCredits() async throws -> WhatsAppCredits { try decode(WhatsAppCredits.self, try await get("whatsapp/credits")) }

    /// `?a=b&…` with empty values left out. `+` and `&` inside a value are escaped (PHP would read `+` as a space).
    nonisolated static func whatsappQuery(_ items: [String: String]) -> String {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        let parts = items.filter { !$0.value.isEmpty }.sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")" }
        return parts.isEmpty ? "" : "?" + parts.joined(separator: "&")
    }
}
