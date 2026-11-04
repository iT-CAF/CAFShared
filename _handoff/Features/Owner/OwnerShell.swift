import SwiftUI

enum OwnerTab: String, Hashable { case overview, team, account }

struct OwnerShell: View {
    @Bindable var store: OwnerStore
    @State private var tab: OwnerTab = .overview

    var body: some View {
        TabView(selection: $tab) {
            OwnerOverviewScreen(store: store)
                .tabItem { Label("owner.tab_overview", systemImage: "chart.bar.xaxis") }.tag(OwnerTab.overview)
            if store.canManage {
                OwnerTeamScreen(store: store)
                    .tabItem { Label("owner.tab_team", systemImage: "person.2.fill") }.tag(OwnerTab.team)
            }
            OwnerAccountScreen(store: store)
                .tabItem { Label("owner.tab_account", systemImage: "person.crop.circle") }.tag(OwnerTab.account)
        }
        .tint(Color.accent)
        .sheet(item: Binding(get: { store.revealedPin }, set: { store.revealedPin = $0 })) { pin in
            PinRevealSheet(reveal: pin) { store.revealedPin = nil }.appLocalized().presentationDetents([.medium])
        }
    }
}

/// Business strip: logo, name (a menu when the account has several businesses) and a reachability hint.
struct OwnerTopBar: View {
    @Bindable var store: OwnerStore
    @Environment(LanguageManager.self) private var lang

    var body: some View {
        HStack(spacing: Space.s) {
            logo
            VStack(alignment: .leading, spacing: 2) {
                if store.businesses.count > 1 {
                    Menu {
                        ForEach(store.businesses) { b in
                            Button { Task { await store.select(b.id) } } label: { Label(b.displayName(english: lang.language == .en), systemImage: b.id == store.selected?.id ? "checkmark" : "building.2") }
                        }
                    } label: {
                        HStack(spacing: 4) { Text(verbatim: name).font(.brandSubheading).lineLimit(1); Image(systemName: "chevron.up.chevron.down").font(.system(size: 11, weight: .semibold)) }
                            .foregroundStyle(Color.textPrimary)
                    }.accessibilityIdentifier("owner.switch_business")
                } else {
                    Text(verbatim: name).font(.brandSubheading).foregroundStyle(Color.textPrimary).lineLimit(1)
                }
                Text(verbatim: store.me?.name.isEmpty == false ? store.me!.name : (store.me?.email ?? "")).font(.brandCaption).foregroundStyle(Color.textMuted).lineLimit(1)
            }
            Spacer(minLength: Space.xs)
            if store.banner != nil { Chip(text: "conn.offline", icon: .alert, tone: .signal) }
        }
        .padding(.horizontal, Space.gutter).padding(.vertical, Space.s)
        .background(Color.surface)
        .overlay(alignment: .bottom) { Divider().overlay(Color.hairline) }
        .accessibilityElement(children: .contain)
    }

    private var name: String { store.selected?.displayName(english: lang.language == .en) ?? "—" }

    @ViewBuilder private var logo: some View {
        if let s = store.selected?.logo, !s.isEmpty, let url = URL(string: s) {
            RemoteImage(url: url, contentMode: .fill, maxPixel: 160) { AvatarCircle(name: name, size: 40) }
                .frame(width: 40, height: 40).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else { AvatarCircle(name: name, size: 40) }
    }
}
