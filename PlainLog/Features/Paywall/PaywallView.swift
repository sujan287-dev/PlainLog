import SwiftUI

/// Pro Paywall — Sprint 5 (PLAN.md Feature 12).
/// Presented as a sheet from wherever the "Pro" trigger lives. Purely a UI
/// wrapper around BillingKit's purchase/restore flows — no merge logic, no
/// server calls, no analytics.
struct PaywallView: View {
    @Environment(BillingKit.self) private var billingKit
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    trustLines
                    featureList

                    if let message = errorMessage {
                        errorBanner(message)
                    }

                    actionButtons
                }
                .padding(24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        // Feature 12: auto-dismiss on a successful purchase. .cancelled and
        // .failed both leave the sheet open — .cancelled is simply never
        // treated as an error state below, which is what "return to idle"
        // means from the user's perspective (BillingKit exposes no setter
        // to literally reset purchaseState, and this piece doesn't touch
        // BillingKit.swift).
        .onChange(of: billingKit.purchaseState) { _, newValue in
            if newValue == .purchased {
                dismiss()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            Text(PaywallCopy.title)
                .font(.largeTitle)
                .bold()
            Text(PaywallCopy.subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Trust lines

    private var trustLines: some View {
        VStack(spacing: 4) {
            Text(PaywallCopy.trustOneTime)
            Text(PaywallCopy.trustNoSubscription)
            Text(PaywallCopy.trustNoAccount)
            Text(PaywallCopy.trustNoData)
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    // MARK: - Feature list

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 10) {
            // "Includes:" is PLAN.md's section label for this list, but it's
            // not one of Feature 12's 12 test-enforced copy constants — kept
            // as a plain literal here rather than added to PaywallCopy.
            Text("Includes:")
                .font(.headline)
            featureRow(PaywallCopy.featureExport)
            featureRow(PaywallCopy.featureThemes)
            featureRow(PaywallCopy.featureFonts)
            featureRow(PaywallCopy.featureFuture)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func featureRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
            Text(text)
        }
    }

    // MARK: - Actions

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                Task { await billingKit.purchase() }
            } label: {
                if isPurchasing {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text(PaywallCopy.buyButton)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isBusy)

            Button {
                Task { await billingKit.restorePurchases() }
            } label: {
                if isRestoring {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text(PaywallCopy.restoreButton)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(isBusy)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.red)
            .multilineTextAlignment(.center)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.red.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Derived state

    private var isPurchasing: Bool {
        billingKit.purchaseState == .purchasing
    }

    private var isRestoring: Bool {
        billingKit.restoreState == .restoring
    }

    private var isBusy: Bool {
        billingKit.purchaseState == .loading
            || billingKit.purchaseState == .purchasing
            || billingKit.restoreState == .restoring
    }

    private var errorMessage: String? {
        if case .failed(let reason) = billingKit.purchaseState {
            return reason
        }
        if case .failed(let reason) = billingKit.restoreState {
            return reason
        }
        return nil
    }
}
