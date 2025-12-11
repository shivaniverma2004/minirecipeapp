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

  
    func add(title: String, description: String? = nil, image: UIImage? = nil) async -> Bool {
        loading = true
        errorMessage = nil
        defer { loading = false }

        do {
            try await supabase.addRecipe(title: title.trimmingCharacters(in: .whitespacesAndNewlines))

            await fetch()
            return true
        } catch {
            self.errorMessage = "Failed to add recipe: \(error.localizedDescription)"
            print("RecipeListViewModel.add error:", error)
            return false
        }
    }

    func refresh() {
        Task { await fetch() }
    }
}
