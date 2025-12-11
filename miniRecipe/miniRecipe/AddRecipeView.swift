//
//  AddRecipeView.swift
//  miniRecipe
//
//  Created by Shivani Verma on 11/12/25.


import SwiftUI

struct AddRecipeView: View {
    @Environment(\.dismiss) var dismiss
    @State private var title = ""
    var onAdded: (() -> Void)? = nil

    @State private var isSaving = false
    @State private var errorMessage: String? = nil
    @State private var showError = false

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Recipe name", text: $title)
                        .autocapitalization(.words)
                }
            }
            .navigationTitle("Add Recipe")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await save()
                        }
                    }
                    .disabled(trimmedTitle.isEmpty || isSaving)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .disabled(isSaving)
            .overlay {
                if isSaving {
                    ProgressView("Saving…")
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.systemBackground)).shadow(radius: 4))
                }
            }
            .alert("Error", isPresented: $showError, actions: {
                Button("OK", role: .cancel) { showError = false }
            }, message: {
                Text(errorMessage ?? "Unknown error")
            })
        }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() async {
        guard !trimmedTitle.isEmpty else { return }
        isSaving = true
        errorMessage = nil

        do {
            try await SupabaseManager.shared.addRecipe(title: trimmedTitle)
            // call optional callback to refresh list
            await MainActor.run {
                onAdded?()
                isSaving = false
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to add recipe: \(error.localizedDescription)"
                showError = true
                isSaving = false
            }
            print("AddRecipeView save error:", error)
        }
    }
}

#if DEBUG
struct AddRecipeView_Previews: PreviewProvider {
    static var previews: some View {
        AddRecipeView {
            print("Added")
        }
    }
}
#endif
