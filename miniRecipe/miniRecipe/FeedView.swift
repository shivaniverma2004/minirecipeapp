//
//  FeedView.swift
//  miniRecipe
//
//  Created by Shivani Verma on 11/12/25.

import SwiftUI
import Foundation

struct FeedView: View {
    @StateObject private var vm = RecipeListViewModel()
    @State private var showAdd = false

    var body: some View {
        NavigationView {
            Group {
                if vm.loading {
                    ProgressView("Loading…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = vm.errorMessage {
                    VStack(spacing: 8) {
                        Text("Error")
                            .font(.headline)
                        Text(err)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    List(vm.recipes) { recipe in
                        NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
                            Text(recipe.title)
                                .lineLimit(1)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("miniRecipe")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add recipe")
                }
            }
            .sheet(isPresented: $showAdd) {
                AddRecipeView {
                    Task { await vm.fetch() }
                }
            }
            .task {
                await vm.fetch()
            }
        }
    }
}

#if DEBUG
struct FeedView_Previews: PreviewProvider {
    static var previews: some View {
        FeedView()
    }
}
#endif
