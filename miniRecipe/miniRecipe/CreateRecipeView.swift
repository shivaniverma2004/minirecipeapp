//
//  CreateRecipeView.swift
//  miniRecipe
//

import SwiftUI
import UIKit

struct CreateRecipeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var supabase: SupabaseManager

    @State private var title: String = ""
    @State private var description: String = ""

    @State private var showingImagePicker = false
    @State private var showingPhotoOptions = false
    @State private var pickedImage: UIImage? = nil
    @State private var pickedImagePreview: Image? = nil

    @State private var isSaving = false
    @State private var alertMessage: String?
    @State private var showAlert = false

    var onCreate: (() -> Void)? = nil

    @State private var imagePickerSourceType: UIImagePickerController.SourceType = .photoLibrary

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Recipe title", text: $title)
                        .textInputAutocapitalization(.words)
                    TextEditor(text: $description)
                        .frame(minHeight: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(uiColor: .tertiarySystemFill), lineWidth: 1)
                        )
                        .padding(.vertical, 4)
                }

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        if let preview = pickedImagePreview {
                            preview
                                .resizable()
                                .scaledToFill()
                                .frame(height: 180)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                                .frame(height: 180)
                                .overlay {
                                    VStack(spacing: 8) {
                                        Image(systemName: "photo.on.rectangle.angled")
                                            .font(.largeTitle)
                                            .foregroundStyle(.secondary)
                                        Text("Add a photo")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                        }
                        HStack {
                            Button {
                                showingPhotoOptions = true
                            } label: {
                                Label("Choose Photo", systemImage: "photo")
                            }
                            Spacer()
                            if pickedImage != nil {
                                Button(role: .destructive) {
                                    pickedImage = nil
                                    pickedImagePreview = nil
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                    }
                } header: {
                    Text("Photo")
                } footer: {
                    Text("JPEG, stored in your Supabase bucket. Public URL is saved on the recipe.")
                }

                if let msg = alertMessage {
                    Section {
                        Text(msg)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("New recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await saveRecipe() }
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(sourceType: imagePickerSourceType, selectedImage: $pickedImage, onComplete: {
                    if let ui = pickedImage {
                        pickedImagePreview = Image(uiImage: ui)
                    }
                })
            }
            .confirmationDialog("Add a photo", isPresented: $showingPhotoOptions) {
                Button("Choose from Library") {
                    imagePickerSourceType = .photoLibrary
                    showingImagePicker = true
                }
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Take Photo") {
                        imagePickerSourceType = .camera
                        showingImagePicker = true
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .onChange(of: pickedImage) { _, newValue in
                if let ui = newValue {
                    pickedImagePreview = Image(uiImage: ui)
                } else {
                    pickedImagePreview = nil
                }
            }
            .alert("Error", isPresented: $showAlert, presenting: alertMessage) { _ in
                Button("OK", role: .cancel) { alertMessage = nil }
            } message: { msg in
                Text(msg)
            }
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func saveRecipe() async {
        guard canSave else { return }
        isSaving = true
        alertMessage = nil

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDesc = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let descriptionToSave = trimmedDesc.isEmpty ? nil : trimmedDesc

        var imageURL: String?
        if let img = pickedImage {
            do {
                let name = "\(UUID().uuidString.lowercased()).jpg"
                imageURL = try await supabase.uploadRecipeImage(img, fileName: name)
            } catch {
                await MainActor.run {
                    alertMessage = UserFacingAPIError.message(for: error)
                    showAlert = true
                    isSaving = false
                }
                return
            }
        }

        do {
            _ = try await supabase.addRecipe(
                title: trimmedTitle,
                description: descriptionToSave,
                imageURL: imageURL
            )

            await MainActor.run {
                onCreate?()
                NotificationCenter.default.post(name: .miniRecipeLibraryDidChange, object: nil)
                isSaving = false
                dismiss()
            }
        } catch {
            await MainActor.run {
                alertMessage = error.localizedDescription
                showAlert = true
                isSaving = false
            }
            AppLog.recipe("create recipe save failed: \(error.localizedDescription)")
        }
    }
}
