//
//  RecipeListViewModel.swift
//  miniRecipe
//
//  Created by Shivani Verma on 11/12/25.
//

import Foundation
import Combine
import SwiftUI

@MainActor
class RecipeListViewModel: ObservableObject {
    @Published var recipes: [Recipe] = []
    @Published var loading: Bool = false
    @Published var errorMessage: String?

    private let supabase = SupabaseManager.shared

    /// Fetch latest recipes (default 100)
    func fetch(limit: Int = 100) async {
        loading = true
        errorMessage = nil
        do {
            let rows = try await supabase.fetchRecipes(limit: limit)
            self.recipes = rows
        } catch {
            self.errorMessage = "Failed to load recipes: \(error.localizedDescription)"
            print("RecipeListViewModel.fetch error:", error)
        }
        loading = false
    }

    /// Add a recipe (current simplified behavior)
    /// NOTE: At the moment SupabaseManager supports addRecipe(title:) only.
    /// This method inserts only the title and then refreshes the list.
    /// If you later enable image upload and addRecipe(title:description:imageURL:),
    /// we'll update this method to upload the image first and include description/imageURL.
    func add(title: String, description: String? = nil, image: UIImage? = nil) async -> Bool {
        loading = true
        errorMessage = nil
        defer { loading = false }

        do {
            // Current manager only supports title-only insert.
            try await supabase.addRecipe(title: title.trimmingCharacters(in: .whitespacesAndNewlines))

            // Refresh list after successful insert
            await fetch()
            return true
        } catch {
            self.errorMessage = "Failed to add recipe: \(error.localizedDescription)"
            print("RecipeListViewModel.add error:", error)
            return false
        }
    }

    /// Simple convenience to refresh and handle errors
    func refresh() {
        Task { await fetch() }
    }
}
