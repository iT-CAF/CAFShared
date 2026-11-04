import SwiftUI

struct OwnerAccountScreen: View {
    @Bindable var store: OwnerStore
    @Environment(AppEnvironment.self) private var env
    @Environment(LanguageManager.self) private var lang
    @State private var confirmOut = false

    var body: some View {
        VStack(spacing: 0) {
            OwnerTopBar(store: store)
            List {
                Section {
                    HStack(spacing: Space.s) {
                        AvatarCircle(name: store.me?.name.isEmpty == false ? store.me!.name : (store.me?.email ?? "?"), size: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: store.me?.name ?? "").font(.brandBodyStrong)
                            Text(verbatim: store.me?.email ?? "").font(.brandCaption).foregroundStyle(Color.textMuted).environment(\.layoutDirection, .leftToRight)
                        }
                    }
                } header: { Text("owner.account").brandSectionHeader() }.listRowBackground(Color.surfaceRaised)

                if store.businesses.count > 1 {
                    Section {
                        ForEach(store.businesses) { b in
                            Button { Task { await store.select(b.id) } } label: {
                                HStack { Text(verbatim: b.displayName(english: lang.language == .en)); Spacer(); if b.id == store.selected?.id { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.success) } }
                            }
                        }
                    } header: { Text("owner.businesses").brandSectionHeader() }.listRowBackground(Color.surfaceRaised)
                }

                Section {
                    Button { env.chooseCashier() } label: { Label("owner.cashier_mode", systemImage: "creditcard.fill") }.accessibilityIdentifier("owner.cashier_mode")
                } header: { Text("owner.modes").brandSectionHeader() } footer: { Text("owner.modes_footer").brandSectionHeader() }.listRowBackground(Color.surfaceRaised)

                Section {
                    ForEach(store.devices) { d in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: d.name.isEmpty ? "—" : d.name).font(.brandBodyStrong)
                                if let t = d.lastUsed ?? d.created { Text(verbatim: Fmt.relative(t)).font(.brandCaption).foregroundStyle(Color.textMuted) }
                            }
                            Spacer()
                            if d.current { Chip(text: "owner.this_device", tone: .success) }
                            else { Button(role: .destructive) { Task { await store.revokeDevice(d.id) } } label: { Text("owner.sign_out_device") }.buttonStyle(.borderless) }
                        }
                    }
                } header: { Text("owner.devices").brandSectionHeader() } footer: { Text("owner.devices_footer").brandSectionHeader() }.listRowBackground(Color.surfaceRaised)

                Section {
                    Picker(selection: Binding(get: { lang.language }, set: { lang.language = $0 })) {
                        ForEach(AppLanguage.allCases) { Text(verbatim: $0.nativeName).tag($0) }
                    } label: { Label("more.language", systemImage: "globe") }
                    LabeledContent("more.version") { Text(verbatim: "\(AppConfig.version) (\(AppConfig.build))").font(.brandMono) }
                    Link("more.privacy", destination: AppConfig.privacyURL)
                    Link("more.terms", destination: AppConfig.termsURL)
                } header: { Text("more.settings").brandSectionHeader() }.listRowBackground(Color.surfaceRaised)

                Section {
                    Button(role: .destructive) { confirmOut = true } label: { Label("owner.sign_out", systemImage: "rectangle.portrait.and.arrow.right") }.accessibilityIdentifier("owner.sign_out")
                }.listRowBackground(Color.surfaceRaised)
            }
            .listStyle(.insetGrouped).scrollContentBackground(.hidden).background(Color.surface)
        }
        .background(Color.surface)
        .task { await store.loadDevices() }
        .confirmationDialog(Text("owner.sign_out_confirm"), isPresented: $confirmOut, titleVisibility: .visible) {
            Button("owner.sign_out", role: .destructive) { Task { await store.signOut() } }
            Button("common.cancel", role: .cancel) {}
        }
    }
}
