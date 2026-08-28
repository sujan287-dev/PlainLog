import Foundation
import SwiftUI

/// Settings screen — Sprint 5 · Piece 5.5 (PLAN.md Feature 11).
/// Five sections in Feature 11's exact order: Folder, Appearance, Summary,
/// Pro, About. Presented as a sheet from EditorView's top-bar gear.
///
/// Folder section note: Feature 11's Folder rows (Current folder / Status /
/// Last successful save / Reconnect folder) already live inside
/// FolderHealthView (reused unmodified, per this piece's scope). That view
/// is its own NavigationStack + List with its own "Done" toolbar button —
/// splicing its internal rows into this Form's Section would nest a List
/// inside a Form row, which SwiftUI renders broken (double scrolling, a
/// squeezed-down NavigationStack). So it's presented here as its own nested
/// sheet instead: a presentation-only adaptation, not a change to the file.
struct SettingsView: View {
    @Environment(AppearanceSettings.self) private var appearanceSettings
    @Environment(BillingKit.self) private var billingKit
    @Environment(SummaryDisplaySettings.self) private var summarySettings
    @Environment(\.dismiss) private var dismiss

    @State private var showingPaywall = false
    @State private var showingFolderHealth = false
    @State private var showingPrivacyPolicy = false

    var body: some View {
        NavigationStack {
            Form {
                folderSection
                appearanceSection
                summarySection
                proSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showingFolderHealth) {
            FolderHealthView()
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicyView()
        }
    }

    // MARK: - Folder

    private var folderSection: some View {
        Section(SettingsCopy.folderSection) {
            Button(SettingsCopy.folderHealthRow) {
                showingFolderHealth = true
            }
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        Section(SettingsCopy.appearanceSection) {
            Picker("Theme", selection: themeBinding) {
                Text("System").tag(Theme.system)
                Text("Light").tag(Theme.light)
                Text("Dark").tag(Theme.dark)
                Text("Sepia").tag(Theme.sepia)
            }
            Picker("Font", selection: fontBinding) {
                Text("System").tag(FontChoice.system)
                Text("Monospaced").tag(FontChoice.monospaced)
            }
            Picker("Font size", selection: fontSizeBinding) {
                Text("Small").tag(FontSize.small)
                Text("Medium").tag(FontSize.medium)
                Text("Large").tag(FontSize.large)
            }
        }
    }

    /// Sepia gate (Feature 12): a plain two-way binding to appearanceSettings.theme
    /// isn't possible (it's private(set)) — this routes every selection through
    /// setTheme(_:isProEnabled:), and opens the paywall instead of applying the
    /// change when the result is .requiresPro. The picker's displayed value stays
    /// correct either way since `get` always reads the model's actual current theme.
    private var themeBinding: Binding<Theme> {
        Binding(
            get: { appearanceSettings.theme },
            set: { newTheme in
                let result = appearanceSettings.setTheme(newTheme, isProEnabled: billingKit.isProEnabled)
                if result == .requiresPro {
                    showingPaywall = true
                }
            }
        )
    }

    private var fontBinding: Binding<FontChoice> {
        Binding(
            get: { appearanceSettings.font },
            set: { appearanceSettings.setFont($0) }
        )
    }

    private var fontSizeBinding: Binding<FontSize> {
        Binding(
            get: { appearanceSettings.fontSize },
            set: { appearanceSettings.setFontSize($0) }
        )
    }

    // MARK: - Summary

    private var summarySection: some View {
        Section(SettingsCopy.summarySection) {
            TextField(SettingsCopy.defaultCurrencySymbol, text: currencySymbolBinding)
            Toggle(SettingsCopy.showExpenseTotal, isOn: showExpenseTotalBinding)
            Toggle(SettingsCopy.showTaskCount, isOn: showTaskCountBinding)
            Toggle(SettingsCopy.showTags, isOn: showTagsBinding)
        }
    }

    private var currencySymbolBinding: Binding<String> {
        Binding(
            get: { summarySettings.defaultCurrencySymbol },
            set: { summarySettings.setDefaultCurrencySymbol($0) }
        )
    }

    private var showExpenseTotalBinding: Binding<Bool> {
        Binding(
            get: { summarySettings.showExpenseTotal },
            set: { summarySettings.setShowExpenseTotal($0) }
        )
    }

    private var showTaskCountBinding: Binding<Bool> {
        Binding(
            get: { summarySettings.showTaskCount },
            set: { summarySettings.setShowTaskCount($0) }
        )
    }

    private var showTagsBinding: Binding<Bool> {
        Binding(
            get: { summarySettings.showTags },
            set: { summarySettings.setShowTags($0) }
        )
    }

    // MARK: - Pro

    private var proSection: some View {
        Section(SettingsCopy.proSection) {
            if billingKit.isProEnabled {
                LabeledContent(PaywallCopy.title, value: "Active")
            } else {
                Button(PaywallCopy.buyButton) {
                    showingPaywall = true
                }
            }
            Button(PaywallCopy.restoreButton) {
                Task { await billingKit.restorePurchases() }
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section(SettingsCopy.aboutSection) {
            LabeledContent(SettingsCopy.version, value: appVersion)
            // Piece 5.10: now presents the full PrivacyPolicyView rather
            // than an inline summary caption — the real policy is one tap
            // away, so the short stance line it used to show here would
            // just duplicate that content.
            Button(SettingsCopy.privacyPolicy) {
                showingPrivacyPolicy = true
            }
            Text(SettingsCopy.support)
        }
    }

    private var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "\u{2014}"
    }
}
