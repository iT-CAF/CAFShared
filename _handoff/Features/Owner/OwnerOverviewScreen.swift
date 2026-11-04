import SwiftUI

struct OwnerOverviewScreen: View {
    @Bindable var store: OwnerStore
    @Environment(LanguageManager.self) private var lang
    @State private var linkTarget: LinkTarget?

    struct LinkTarget: Identifiable { let id: Int; let name: String; let url: String }

    var body: some View {
        VStack(spacing: 0) {
            OwnerTopBar(store: store)
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    if let b = store.banner { ErrorBanner(message: b, onRetry: { Task { await store.refreshOverview() } }) }
                    if let o = store.overview {
                        SectionHeader(title: "owner.today")
                        tiles(o)
                        SectionHeader(title: "owner.branches")
                        if o.branches.isEmpty { EmptyState(icon: .branch, title: "owner.no_branches", message: "owner.no_branches_body") }
                        ForEach(o.branches) { b in
                            Button { if let u = b.cashier { linkTarget = LinkTarget(id: b.id, name: b.name, url: u) } } label: { BranchCard(branch: b) }
                                .buttonStyle(.plain).accessibilityIdentifier("owner.branch.\(b.id)")
                        }
                    } else if store.banner == nil {
                        VStack(spacing: Space.s) { SkeletonCard(); SkeletonCard(); SkeletonCard() }
                    }
                }
                .padding(.horizontal, Space.gutter).padding(.vertical, Space.m)
                .frame(maxWidth: 720).frame(maxWidth: .infinity)
            }
            .refreshable { await store.refreshOverview() }
        }
        .background(Color.surface)
        .task { await store.pollOverview() }
        .sheet(item: $linkTarget) { t in BranchLinkSheet(name: t.name, url: t.url, rotate: nil).appLocalized() }
    }

    @ViewBuilder private func tiles(_ o: OwnerOverview) -> some View {
        let t = o.business.tools, c = o.cards
        LazyVGrid(columns: [GridItem(.flexible(), spacing: Space.s), GridItem(.flexible(), spacing: Space.s)], spacing: Space.s) {
            if t.drive || t.pager {
                StatTile(titleKey: "owner.t_orders", value: Fmt.number(c.orders), icon: "bag.fill", tone: .accent).accessibilityIdentifier("owner.tile.orders")
                StatTile(titleKey: "owner.t_waiting", value: Fmt.number(c.waiting), icon: "hourglass", tone: c.waiting > 0 ? .signal : .neutral).accessibilityIdentifier("owner.tile.waiting")
                if let p = c.prepAvg { StatTile(titleKey: "owner.t_prep", value: Fmt.number(p), unit: L10n.string("owner.minutes"), icon: "timer") }
            }
            if t.loyalty {
                StatTile(titleKey: "owner.t_members", value: Fmt.number(c.membersNew), icon: "person.badge.plus").accessibilityIdentifier("owner.tile.members")
                StatTile(titleKey: "owner.t_stamps", value: Fmt.number(c.stamps), icon: "star.fill").accessibilityIdentifier("owner.tile.stamps")
                StatTile(titleKey: "owner.t_rewards", value: Fmt.number(c.rewards), icon: "gift.fill", tone: c.rewards > 0 ? .success : .neutral)
            }
        }
    }
}

private struct BranchCard: View {
    let branch: OwnerLiveBranch
    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(spacing: Space.xs) {
                Text(verbatim: branch.name).font(.brandSubheading).foregroundStyle(Color.textPrimary).lineLimit(1)
                Spacer(minLength: Space.xs)
                if !branch.active { Chip(text: "owner.branch_off", icon: .lock, tone: .neutral) }
                else if branch.paused { Chip(text: "state.paused", icon: .alert, tone: .signal) }
                else { Chip(text: branch.online ? "conn.online" : "conn.offline", icon: .clock, tone: branch.online ? .success : .neutral) }
            }
            if branch.capacity > 0 {
                HStack(spacing: Space.xs) {
                    ProgressView(value: min(1, Double(branch.openOrders) / Double(max(1, branch.capacity)))).tint(loadTone)
                    Text(verbatim: "\(Fmt.number(branch.openOrders)) / \(Fmt.number(branch.capacity))").font(.brandMonoSmall).foregroundStyle(Color.textMuted)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: L10n.string("owner.load_a11y", branch.openOrders, branch.capacity)))
            }
            if !branch.staff.isEmpty {
                HStack(spacing: 6) { IconView(icon: .user, size: 14); Text(verbatim: branch.staff.joined(separator: "، ")).lineLimit(1) }
                    .font(.brandCaption).foregroundStyle(Color.textMuted)
            }
            if let seen = branch.seen {
                Text(verbatim: L10n.string("owner.last_seen", Fmt.relative(seen))).font(.brandCaption).foregroundStyle(Color.textMuted)
            }
        }
        .padding(Space.m).frame(maxWidth: .infinity, alignment: .leading).brandCardBackground()
        .accessibilityElement(children: .combine)
    }
    private var loadTone: Color { switch branch.load { case .calm: .successFill; case .busy: .accentFill; case .full: .signalFill } }
}
