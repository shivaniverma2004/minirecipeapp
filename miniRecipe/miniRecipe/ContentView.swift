//
//  ContentView.swift
//  miniRecipe
//
//  Created by Shivani Verma on 11/12/25.
//

import SwiftUI

struct ContentView: View {

    @EnvironmentObject private var supabase: SupabaseManager
    @StateObject private var feed = RecipeFeedViewModel()

    @State private var showCreate = false
    @State private var showAuthSheet = false
    @State private var recipePendingDelete: Recipe?
    @State private var deleteError: String?
    @State private var showDeleteError = false

    private var recipesToShow: [Recipe] { feed.filteredRecipes }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let banner = feed.staleLoadBanner {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "wifi.exclamationmark")
                            .foregroundStyle(.orange)
                            .accessibilityHidden(true)
                        Text(banner)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Spacer(minLength: 8)
                        Button("Dismiss") {
                            feed.dismissStaleBanner()
                        }
                        .font(.subheadline.weight(.semibold))
                        .accessibilityLabel("Dismiss offline warning")
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal)
                }

                Group {
                    if feed.isLoading && recipesToShow.isEmpty && feed.fullScreenError == nil {
                        ProgressView("Loading recipes…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let error = feed.fullScreenError {
                        ContentUnavailableView {
                            Label("Couldn’t load recipes", systemImage: "exclamationmark.triangle")
                        } description: {
                            Text(error)
                                .multilineTextAlignment(.center)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } actions: {
                            Button("Try again") {
                                Task { await feed.load() }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    } else if recipesToShow.isEmpty {
                        ContentUnavailableView {
                            Label(
                                feed.searchText.isEmpty ? "No recipes yet" : "No matches",
                                systemImage: "book.closed"
                            )
                        } description: {
                            Text(emptyDescription)
                                .multilineTextAlignment(.center)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } actions: {
                            if supabase.isSignedIn {
                                Button {
                                    showCreate = true
                                } label: {
                                    Text("New recipe")
                                }
                                .buttonStyle(.borderedProminent)
                            } else {
                                Button("Sign in") { showAuthSheet = true }
                                    .buttonStyle(.borderedProminent)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(recipesToShow) { recipe in
                                NavigationLink(value: recipe) {
                                    RecipeRow(recipe: recipe)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    if supabase.currentUserIdString == recipe.authorID {
                                        Button(role: .destructive) {
                                            recipePendingDelete = recipe
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                        .scrollContentBackground(.hidden)
                        .navigationDestination(for: Recipe.self) { recipe in
                            RecipeDetailView(recipe: recipe)
                                .environmentObject(supabase)
                        }
                    }
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Recipes")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $feed.searchText, prompt: "Search recipes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if supabase.isSignedIn {
                            showCreate = true
                        } else {
                            showAuthSheet = true
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                    }
                    .accessibilityLabel("Create recipe")
                }

                ToolbarItem(placement: .topBarLeading) {
                    if !supabase.isSignedIn {
                        Button("Sign in") { showAuthSheet = true }
                            .font(.subheadline.weight(.medium))
                    }
                }
            }
            .refreshable { await feed.load() }
            .task { await feed.load() }
            .sheet(isPresented: $showCreate) {
                CreateRecipeView {
                    Task { await feed.load() }
                }
                .environmentObject(supabase)
            }
            .sheet(isPresented: $showAuthSheet) {
                AuthView(showsDismissButton: true) { success in
                    showAuthSheet = false
                    if success {
                        Task { await feed.load() }
                    }
                }
            }
            .onChange(of: supabase.isSignedIn) { _, _ in
                Task { await feed.load() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .miniRecipeLibraryDidChange)) { _ in
                Task { await feed.load() }
            }
            .confirmationDialog(
                "Delete this recipe?",
                isPresented: Binding(
                    get: { recipePendingDelete != nil },
                    set: { if !$0 { recipePendingDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let r = recipePendingDelete {
                        Task { await performDelete(r) }
                    }
                    recipePendingDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    recipePendingDelete = nil
                }
            } message: {
                if let r = recipePendingDelete {
                    Text("“\(r.title)” will be removed for everyone.")
                }
            }
            .alert("Couldn’t delete", isPresented: $showDeleteError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(deleteError ?? "")
            }
        }
    }

    private func performDelete(_ recipe: Recipe) async {
        do {
            try await supabase.deleteRecipe(id: recipe.id)
            NotificationCenter.default.post(name: .miniRecipeLibraryDidChange, object: nil)
            await feed.load()
        } catch {
            deleteError = error.localizedDescription
            showDeleteError = true
        }
    }

    private var emptyDescription: String {
        if !feed.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Try a different search term."
        }
        if supabase.isSignedIn {
            return "Create your first recipe or pull down to refresh."
        }
        return "Sign in to add recipes, or browse once your project allows public reads."
    }
}
