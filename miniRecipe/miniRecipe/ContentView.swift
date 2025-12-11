//
//  ContentView.swift
//  miniRecipe
//
//  Created by Shivani Verma on 11/12/25. 
//

import SwiftUI

struct ContentView: View {

    @StateObject private var supabaseManager = SupabaseManager.shared

    @State private var recipes: [Recipe] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    // UI
    @State private var showCreate = false
    @State private var showAuthSheet = false

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading recipes...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    VStack(spacing: 12) {
                        Text("Error")
                            .font(.title2)
                        Text(error)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task { await loadRecipes() }
                        }
                    }
                    .padding()
                } else if recipes.isEmpty {
                    VStack(spacing: 12) {
                        Text("No recipes yet")
                            .font(.title2)
                        Text("Tap + to create the first recipe.")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(recipes) { recipe in
                            NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
                                RecipeRow(recipe: recipe)
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("miniRecipe")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        if supabaseManager.isSignedIn {
                            showCreate = true
                        } else {
                            // Not signed in — open auth sheet
                            showAuthSheet = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Create Recipe")
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    if supabaseManager.isSignedIn {
                        Button("Sign out") {
                            Task {
                                do {
                                    try await supabaseManager.signOut()
                                    await loadRecipes()
                                } catch {
                                    print("Sign out failed:", error)
                                }
                            }
                        }
                    } else {
                        Button("Sign in") { showAuthSheet = true }
                    }
                }
            }
            .refreshable { await loadRecipes() }
            .task { await loadRecipes() }
            // MARK: - Sheets
            .sheet(isPresented: $showCreate) {
                // The image-capable create view
                CreateRecipeView {
                    Task { await loadRecipes() }
                }
            }
            .sheet(isPresented: $showAuthSheet) {
                AuthView { success in
                    showAuthSheet = false
                    if success {
                        Task { await loadRecipes() }
                    }
                }
            }
            .onChange(of: supabaseManager.isSignedIn) { _ in
                Task { await loadRecipes() }
            }
        }
    }

    // MARK: - Networking
    func loadRecipes() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        defer { Task { await MainActor.run { isLoading = false } } }

        do {
            let rows = try await supabaseManager.fetchRecipes(limit: 100)
            await MainActor.run { self.recipes = rows }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load recipes: \(error.localizedDescription)"
            }
            print("loadRecipes error:", error)
        }
    }
}

// MARK: - Preview
#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(SupabaseManager.shared)
    }
}
#endif
