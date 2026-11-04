import SwiftUI

struct OwnerTeamScreen: View {
    @Bindable var store: OwnerStore
    @State private var addBranch = false
    @State private var addStaff = false
    @State private var detail: OwnerBranch?
    @State private var confirmRotate: OwnerBranch?
    @State private var confirmReset: OwnerStaff?

    var body: some View {
        VStack(spacing: 0) {
            OwnerTopBar(store: store)
            List {
                if let b = store.banner { Section { ErrorBanner(message: b, onRetry: { Task { await store.loadTeam() } }) }.listRowBackground(Color.clear) }
                if let team = store.team {
                    Section {
                        ForEach(team.branches) { b in
                            Button { detail = b } label: { branchRow(b) }.accessibilityIdentifier("owner.team.branch.\(b.id)")
                        }
                        Button { addBranch = true } label: { Label("owner.add_branch", systemImage: "plus.circle.fill") }.accessibilityIdentifier("owner.add_branch")
                            .disabled(team.limits.map { team.branches.count >= $0.branches } ?? false)
                    } header: { Text("owner.branches").brandSectionHeader() }.listRowBackground(Color.surfaceRaised)

                    Section {
                        ForEach(team.staff) { s in staffRow(s) }
                        Button { addStaff = true } label: { Label("owner.add_staff", systemImage: "person.badge.plus") }.accessibilityIdentifier("owner.add_staff")
                            .disabled(team.limits.map { team.staff.count >= $0.staff } ?? false)
                    } header: { Text("owner.staff").brandSectionHeader() } footer: { Text("owner.staff_footer").brandSectionHeader() }.listRowBackground(Color.surfaceRaised)
                } else if store.banner == nil {
                    Section { SkeletonCard() }.listRowBackground(Color.clear)
                }
            }
            .listStyle(.insetGrouped).scrollContentBackground(.hidden).background(Color.surface)
            .refreshable { await store.loadTeam() }
        }
        .background(Color.surface)
        .task { await store.loadTeam() }
        .sheet(isPresented: $addBranch) { AddBranchSheet(store: store).appLocalized().presentationDetents([.medium]) }
        .sheet(isPresented: $addStaff) { AddStaffSheet(store: store).appLocalized().presentationDetents([.large]) }
        .sheet(item: $detail) { b in
            BranchLinkSheet(name: liveBranch(b).name, url: liveBranch(b).cashier, rotate: { confirmRotate = liveBranch(b) }, active: liveBranch(b).active, toggle: { Task { await store.toggleBranch(b.id) } }).appLocalized()
                .confirmationDialog(Text("owner.rotate_confirm"), isPresented: Binding(get: { confirmRotate != nil }, set: { if !$0 { confirmRotate = nil } }), titleVisibility: .visible) {
                    Button("owner.rotate", role: .destructive) { if let r = confirmRotate { Task { await store.rotateLink(r) } }; confirmRotate = nil }
                    Button("common.cancel", role: .cancel) { confirmRotate = nil }
                } message: { Text("owner.rotate_body") }
        }
        .confirmationDialog(Text("owner.reset_confirm"), isPresented: Binding(get: { confirmReset != nil }, set: { if !$0 { confirmReset = nil } }), titleVisibility: .visible) {
            Button("owner.reset_pin", role: .destructive) { if let s = confirmReset { Task { await store.resetPin(s) } }; confirmReset = nil }
            Button("common.cancel", role: .cancel) { confirmReset = nil }
        } message: { Text("owner.reset_body") }
    }

    private func liveBranch(_ b: OwnerBranch) -> OwnerBranch { store.team?.branches.first { $0.id == b.id } ?? b }

    private func branchRow(_ b: OwnerBranch) -> some View {
        HStack(spacing: Space.s) {
            ZStack { RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.accent.opacity(0.14)); IconView(icon: .branch, size: 20).foregroundStyle(Color.accent) }.frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: b.name).font(.brandBodyStrong).foregroundStyle(Color.textPrimary)
                HStack(spacing: 6) {
                    if let a = b.address, !a.isEmpty { Text(verbatim: a).lineLimit(1); Text(verbatim: "·") }
                    Text(verbatim: L10n.string("owner.staff_count", b.staffCount))
                }.font(.brandCaption).foregroundStyle(Color.textMuted)
            }
            Spacer(minLength: Space.xs)
            if !b.active { Chip(text: "owner.branch_off", tone: .neutral) }
            IconView(icon: .arrow, size: 16).foregroundStyle(Color.textMuted)
        }
        .contentShape(Rectangle())
    }

    private func staffRow(_ s: OwnerStaff) -> some View {
        HStack(spacing: Space.s) {
            AvatarCircle(name: s.name, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: s.name).font(.brandBodyStrong).foregroundStyle(s.active ? Color.textPrimary : Color.textMuted)
                HStack(spacing: 6) {
                    Text(LocalizedStringKey("role.\(s.role)"))
                    if let bn = s.branchName { Text(verbatim: "·"); Text(verbatim: bn).lineLimit(1) }
                }.font(.brandCaption).foregroundStyle(Color.textMuted)
            }
            Spacer(minLength: Space.xs)
            if s.locked { Chip(text: "owner.locked", icon: .lock, tone: .signal) } else if !s.active { Chip(text: "owner.inactive", tone: .neutral) }
            Menu {
                Button { confirmReset = s } label: { Label("owner.reset_pin", systemImage: "key.fill") }
                Button { Task { await store.toggleStaff(s.id) } } label: { Label(s.active ? "owner.deactivate" : "owner.activate", systemImage: s.active ? "pause.circle" : "play.circle") }
            } label: { Image(systemName: "ellipsis.circle").font(.system(size: 22)).foregroundStyle(Color.textMuted).frame(width: 44, height: 44) }
            .accessibilityLabel(Text("owner.staff_actions")).accessibilityIdentifier("owner.staff.menu.\(s.id)")
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: sheets

struct AddBranchSheet: View {
    @Bindable var store: OwnerStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var address = ""
    @State private var saving = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Space.m) {
                    FormField(label: "owner.branch_name", text: $name, placeholder: "owner.branch_name_placeholder", icon: .branch, capitalization: .words, identifier: "owner.branch_name")
                    FormField(label: "owner.branch_address", text: $address, placeholder: "owner.branch_address_placeholder", icon: .folder, capitalization: .sentences, submitLabel: .done, identifier: "owner.branch_address")
                    if let b = store.banner { Text(verbatim: b).font(.brandSmall).foregroundStyle(Color.signal).frame(maxWidth: .infinity, alignment: .leading) }
                    BrandButton(title: "common.save", isLoading: saving) {
                        saving = true
                        Task { if await store.createBranch(name: name.trimmingCharacters(in: .whitespaces), address: address.trimmingCharacters(in: .whitespaces)) { dismiss() }; saving = false }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).count < 2).accessibilityIdentifier("owner.branch_save")
                }.padding(Space.gutter)
            }
            .background(Color.surface).brandNavTitle("owner.add_branch")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("common.cancel") { dismiss() } } }
        }
    }
}

struct AddStaffSheet: View {
    @Bindable var store: OwnerStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var role = "cashier"
    @State private var branch: Int?
    @State private var saving = false
    static let roles = ["cashier", "manager", "handover", "preparer", "loyalty"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.m) {
                    FormField(label: "owner.staff_name", text: $name, placeholder: "owner.staff_name_placeholder", icon: .user, capitalization: .words, submitLabel: .done, identifier: "owner.staff_name")
                    VStack(alignment: .leading, spacing: 6) {
                        Text("owner.role").font(.brandCaption).foregroundStyle(Color.textMuted)
                        ForEach(Self.roles, id: \.self) { r in
                            Button { role = r } label: {
                                HStack { Text(LocalizedStringKey("role.\(r)")).font(.brandBody); Spacer(); if role == r { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accent) } }
                                    .padding(Space.s).frame(minHeight: 44).brandCardBackground(radius: Radius.control)
                            }.buttonStyle(.plain).accessibilityIdentifier("owner.role.\(r)").accessibilityAddTraits(role == r ? .isSelected : [])
                        }
                        Text(LocalizedStringKey("owner.role_hint_\(role)")).font(.brandCaption).foregroundStyle(Color.textMuted)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("owner.branch").font(.brandCaption).foregroundStyle(Color.textMuted)
                        Picker("owner.branch", selection: $branch) {
                            Text("owner.all_branches").tag(Int?.none)
                            ForEach(store.team?.branches ?? []) { Text(verbatim: $0.name).tag(Int?.some($0.id)) }
                        }.pickerStyle(.menu).tint(Color.accentText).accessibilityIdentifier("owner.staff_branch")
                    }
                    Text("owner.pin_note").font(.brandCaption).foregroundStyle(Color.textMuted)
                    if let b = store.banner { Text(verbatim: b).font(.brandSmall).foregroundStyle(Color.signal) }
                    BrandButton(title: "owner.create_staff", isLoading: saving) {
                        saving = true
                        Task { if await store.createStaff(name: name.trimmingCharacters(in: .whitespaces), role: role, branch: branch) { dismiss() }; saving = false }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).count < 2).accessibilityIdentifier("owner.staff_save")
                }.padding(Space.gutter)
            }
            .background(Color.surface).brandNavTitle("owner.add_staff")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("common.cancel") { dismiss() } } }
        }
    }
}

/// The PIN the server generated, shown once. It is never stored and the server only keeps its hash.
struct PinRevealSheet: View {
    let reveal: OwnerStore.RevealedPin
    let onDone: () -> Void
    @State private var copied = false

    var body: some View {
        VStack(spacing: Space.m) {
            Text("owner.pin_title").font(.brandHeading).foregroundStyle(Color.textPrimary).padding(.top, Space.l)
            Text(verbatim: reveal.staffName).font(.brandBodyStrong).foregroundStyle(Color.textMuted)
            Text(verbatim: reveal.pin).font(.brandMono(size: 44, bold: true)).tracking(6).foregroundStyle(Color.accentText).environment(\.layoutDirection, .leftToRight)
                .padding(.horizontal, Space.l).padding(.vertical, Space.s).brandCardBackground().accessibilityIdentifier("owner.pin_value").accessibilityLabel(Text(verbatim: reveal.pin.map(String.init).joined(separator: " ")))
            Text("owner.pin_once").font(.brandSmall).foregroundStyle(Color.textMuted).multilineTextAlignment(.center)
            HStack(spacing: Space.s) {
                BrandButton(title: copied ? "owner.copied" : "owner.copy", icon: .file, kind: .secondary) { SecretClipboard.copy(reveal.pin); copied = true }
                BrandButton(title: "common.done", action: onDone).accessibilityIdentifier("owner.pin_done")
            }
        }
        .padding(Space.gutter).frame(maxWidth: .infinity).background(Color.surface)
    }
}
