//
//  RecipeFeedViewModel.swift
//  miniRecipe
//

import Foundation
import Combine

@MainActor
final class RecipeFeedViewModel: ObservableObject {

    @Published private(set) var recipes: [Recipe] = []
    @Published private(set) var isLoading = false
    /// Shown as full-screen error only when there is no cached list to show.
    @Published var fullScreenError: String?
    /// Shown as a banner when refresh failed but an older list is still visible.
    @Published var staleLoadBanner: String?
    @Published var searchText: String = ""

    private var lastSuccessfulRecipes: [Recipe] = []
    private let supabase = SupabaseManager.shared

    var filteredRecipes: [Recipe] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return recipes }
        return recipes.filter { recipe in
            recipe.title.lowercased().contains(q)
                || (recipe.description?.lowercased().contains(q) ?? false)
        }
    }

    func load() async {
        isLoading = true
        fullScreenError = nil
        defer { isLoading = false }

        do {
            let rows = try await supabase.fetchRecipes(limit: 100)
            recipes = rows
            lastSuccessfulRecipes = rows
            staleLoadBanner = nil
        } catch {
            let message = UserFacingAPIError.message(for: error)
            AppLog.feed("load failed: \(error.localizedDescription)")

            if !lastSuccessfulRecipes.isEmpty {
                recipes = lastSuccessfulRecipes
                staleLoadBanner = message
            } else {
                fullScreenError = message
            }
        }
    }

    func dismissStaleBanner() {
        staleLoadBanner = nil
    }
}
