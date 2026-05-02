//
//  EditRecipeView.swift
//  miniRecipe
//

import SwiftUI
import UIKit

struct EditRecipeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var supabase: SupabaseManager

    let recipe: Recipe
    var onSaved: (() -> Void)?

    @State private var title: String
    @State private var description: String
    @State private var pickedImage: UIImage?
    @State private var pickedPreview: Image?
    @State private var showPhotoOptions = false
    @State private var showPicker = false
    @State private var pickerSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var isSaving = false
    @State private var alertMessage: String?
    @State private var showAlert = false

    init(recipe: Recipe, onSaved: (() -> Void)? = nil) {
        self.recipe = recipe
        self.onSaved = onSaved
        _title = State(initialValue: recipe.title)
        _description = State(initialValue: recipe.description ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.words)
                    TextEditor(text: $description)
                        .frame(minHeight: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(uiColor: .tertiarySystemFill), lineWidth: 1)
                        )
                }
                Section("Photo") {
                    if let preview = pickedPreview {
                        preview
                            .resizable()
                            .scaledToFill()
                            .frame(height: 160)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else if let urlString = recipe.imageURL?.trimmingCharacters(in: .whitespacesAndNewlines), !urlString.isEmpty {
                        RemoteImage(urlString: recipe.imageURL, version: 0, contentMode: .fill)
                            .frame(height: 160)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    Button("Change photo") { showPhotoOptions = true }
                }
            }
            .navigationTitle("Edit recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!canSave || isSaving)
                }
            }
            .confirmationDialog("Photo", isPresented: $showPhotoOptions) {
                Button("Library") {
                    pickerSource = .photoLibrary
                    showPicker = true
                }
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Camera") {
                        pickerSource = .camera
                        showPicker = true
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showPicker) {
                ImagePicker(sourceType: pickerSource, selectedImage: $pickedImage, onComplete: {
                    if let ui = pickedImage {
                        pickedPreview = Image(uiImage: ui)
                    }
                })
            }
            .onChange(of: pickedImage) { _, new in
                if let ui = new { pickedPreview = Image(uiImage: ui) }
            }
            .alert("Error", isPresented: $showAlert, presenting: alertMessage) { _ in
                Button("OK", role: .cancel) {}
            } message: { m in
                Text(m)
            }
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        var imageURL = recipe.imageURL
        if let img = pickedImage {
            do {
                let name = "\(UUID().uuidString.lowercased()).jpg"
                imageURL = try await supabase.uploadRecipeImage(img, fileName: name)
            } catch {
                alertMessage = error.localizedDescription
                showAlert = true
                return
            }
        }
        do {
            try await supabase.updateRecipe(
                id: recipe.id,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                imageURL: imageURL
            )
            NotificationCenter.default.post(name: .miniRecipeLibraryDidChange, object: nil)
            onSaved?()
            dismiss()
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
