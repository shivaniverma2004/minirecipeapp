//
//  CreateRecipeView.swift
//  miniRecipe
//
//  Created by Shivani Verma on 11/12/25.


import SwiftUI
import UIKit

struct CreateRecipeView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var supabase = SupabaseManager.shared

    // Form fields
    @State private var title: String = ""
    @State private var description: String = ""

    // Image picker state 
    @State private var showingImagePicker = false
    @State private var showingPhotoOptions = false
    @State private var pickedImage: UIImage? = nil
    @State private var pickedImagePreview: Image? = nil

    // UI state
    @State private var isSaving = false
    @State private var alertMessage: String?
    @State private var showAlert = false

    // completion callback so caller refreshes list
    var onCreate: (() -> Void)? = nil

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Details")) {
                    TextField("Recipe title", text: $title)
                        .autocapitalization(.words)
                    TextEditor(text: $description)
                        .frame(minHeight: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(UIColor.tertiarySystemFill), lineWidth: 1)
                        )
                        .padding(.vertical, 4)
                }

                Section(header: Text("Image (disabled until storage is configured)")) {
                    VStack {
                        if let preview = pickedImagePreview {
                            preview
                                .resizable()
                                .scaledToFill()
                                .frame(height: 180)
                                .clipped()
                                .cornerRadius(8)
                                .padding(.bottom, 8)
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(UIColor.secondarySystemBackground))
                                .frame(height: 180)
                                .overlay(
                                    VStack {
                                        Image(systemName: "photo.on.rectangle.angled")
                                            .font(.largeTitle)
                                            .foregroundColor(.secondary)
                                        Text("Image preview will work once upload is enabled")
                                            .foregroundColor(.secondary)
                                            .font(.footnote)
                                            .multilineTextAlignment(.center)
                                    }
                                    .padding()
                                )
                                .padding(.bottom, 8)
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
                }

                if let msg = alertMessage {
                    Section {
                        Text(msg)
                            .foregroundColor(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Create Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await saveRecipe() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save").bold()
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
                    } else {
                        pickedImagePreview = nil
                    }
                })
            }
            .actionSheet(isPresented: $showingPhotoOptions) {
                ActionSheet(title: Text("Photo"), message: nil, buttons: [
                    .default(Text("Choose from Library")) {
                        imagePickerSourceType = .photoLibrary
                        showingImagePicker = true
                    },
                    .default(Text("Take Photo")) {
                        imagePickerSourceType = .camera
                        showingImagePicker = true
                    },
                    .cancel()
                ])
            }
            .onChange(of: pickedImage) { newValue in
                if let ui = newValue {
                    pickedImagePreview = Image(uiImage: ui)
                } else {
                    pickedImagePreview = nil
                }
            }
            .alert("Error", isPresented: $showAlert, presenting: alertMessage) { _ in
                Button("OK", role: .cancel) { alertMessage = nil }
            } message: { msg in
                Text(msg ?? "Unknown error")
            }
        }
    }

    // local image picker source type
    @State private var imagePickerSourceType: UIImagePickerController.SourceType = .photoLibrary

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Save flow (current simplified behavior):
    /// - This version **only inserts the title** via `SupabaseManager.addRecipe(title:)`
    /// - If you want image upload and description stored, we will enable it after updating SupabaseManager.
    private func saveRecipe() async {
        guard canSave else { return }
        isSaving = true
        alertMessage = nil

        do {
            // NOTE: current SupabaseManager only supports addRecipe(title:).
            // We preserve description and image UI for future use.
            try await supabase.addRecipe(title: title.trimmingCharacters(in: .whitespacesAndNewlines))

            await MainActor.run {
                onCreate?()
                isSaving = false
                dismiss()
            }
        } catch {
            await MainActor.run {
                alertMessage = "Failed to create recipe: \(error.localizedDescription)"
                showAlert = true
                isSaving = false
            }
            print("CreateRecipeView save error:", error)
        }
    }
}

// MARK: - UIImagePickerController wrapper for SwiftUI
struct ImagePicker: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @Binding var selectedImage: UIImage?
    var onComplete: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        picker.allowsEditing = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // no-op
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.selectedImage = nil
            parent.onComplete?()
            picker.dismiss(animated: true)
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            var selected: UIImage?

            if let edited = info[.editedImage] as? UIImage {
                selected = edited
            } else if let original = info[.originalImage] as? UIImage {
                selected = original
            }

            parent.selectedImage = selected
            parent.onComplete?()
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Preview
#if DEBUG
struct CreateRecipeView_Previews: PreviewProvider {
    static var previews: some View {
        CreateRecipeView {
            // preview callback
        }
    }
}
#endif
