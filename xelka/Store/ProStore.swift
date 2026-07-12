//
//  ProStore.swift
//  xelka
//
//  Owns the app's single in-app purchase: a one-time "xelka Pro" unlock
//  (non-consumable) that removes the export watermark and unlocks the premium
//  styles and video/GIF recording. StoreKit 2 is the source of truth — `isPro`
//  is recomputed from `Transaction.currentEntitlements`, never persisted by us,
//  so it survives reinstalls and restores automatically.
//

import StoreKit
import Observation

@MainActor
@Observable
final class ProStore {
    /// Must match the productID in `xelka.storekit` (and later App Store Connect).
    static let productID = "com.jimmythegenius.xelka.pro"

    /// The loaded product, for price display on the paywall (nil until fetched).
    private(set) var product: Product?
    /// Whether the Pro unlock is currently owned. Drives every gate in the app.
    private(set) var isPro = false
    /// True while a product fetch or purchase is in flight (paywall spinner).
    private(set) var isWorking = false
    /// Last user-facing error, if any (surfaced by the paywall).
    var errorMessage: String?

    // Cancelled from the nonisolated deinit; a Task handle is Sendable and its
    // cancel() is safe from any thread.
    nonisolated(unsafe) private var updatesTask: Task<Void, Never>?

    init() {
        // Catch transactions that arrive outside an explicit purchase() call:
        // Ask-to-Buy approvals, purchases made on another device, revocations.
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.finish(update)
            }
        }
        Task { await refresh() }
    }

    deinit { updatesTask?.cancel() }

    /// Load product metadata and reconcile the current entitlement. Safe to call
    /// repeatedly (e.g. when the paywall appears).
    func refresh() async {
        await loadProduct()
        await updateEntitlement()
    }

    /// Fetch the Pro product once (keeps the cached copy on repeat calls).
    func loadProduct() async {
        guard product == nil else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            product = try await Product.products(for: [Self.productID]).first
        } catch {
            errorMessage = "Couldn't reach the App Store. Check your connection."
        }
    }

    /// Recompute `isPro` from StoreKit's verified entitlements.
    func updateEntitlement() async {
        var owned = false
        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement else { continue }
            if transaction.productID == Self.productID, transaction.revocationDate == nil {
                owned = true
            }
        }
        isPro = owned
    }

    /// Start a purchase. Returns true once Pro is unlocked.
    @discardableResult
    func purchase() async -> Bool {
        if product == nil { await loadProduct() }
        guard let product else {
            errorMessage = "The Pro upgrade is unavailable right now."
            return false
        }
        isWorking = true
        defer { isWorking = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                await finish(verification)
                return isPro
            case .userCancelled:
                return false
            case .pending:
                // Deferred (e.g. Ask to Buy). Transaction.updates will resolve it.
                return false
            @unknown default:
                return false
            }
        } catch {
            errorMessage = "Purchase failed. Please try again."
            return false
        }
    }

    /// Restore a previous purchase by syncing with the App Store.
    func restore() async {
        isWorking = true
        defer { isWorking = false }
        try? await AppStore.sync()
        await updateEntitlement()
    }

    /// Finalize a verified transaction and refresh entitlement state.
    private func finish(_ verification: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = verification else { return }
        await transaction.finish()
        await updateEntitlement()
    }
}
