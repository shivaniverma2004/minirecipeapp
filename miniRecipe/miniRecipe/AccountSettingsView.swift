//
//  AccountSettingsView.swift
//  miniRecipe
//

import Auth
import SwiftUI
import UIKit

struct AccountSettingsView: View {
    @EnvironmentObject private var supabase: SupabaseManager
    @Environment(\.dismiss) private var dismiss

    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var savingPassword = false
    @State private var passwordMessage: String?
    @State private var showPasswordSuccess = false

    @State private var displayName = ""
    @State private var savedAvatarURL: String?
    @State private var pickedAvatar: UIImage?
    @State private var showPhotoOptions = false
    @State private var showPicker = false
    @State private var pickerSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var savingProfile = false
    @State private var profileMessage: String?
    @State private var showProfileAlert = false
    @State private var avatarPreviewVersion = 0

    private var trimmedName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSaveProfile: Bool {
        if savingProfile { return false }
        if pickedAvatar != nil { return true }
        return !trimmedName.isEmpty
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Preview")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 16) {
                        Group {
                            if let img = pickedAvatar {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                AvatarView(
                                    urlString: savedAvatarURL,
                                    initials: previewInitials,
                                    size: 72,
                                    imageVersion: avatarPreviewVersion
                                )
                            }
                        }
                        .frame(width: 72, height: 72)
                        .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 6) {
                            Text(trimmedName.isEmpty ? "Your name" : trimmedName)
                                .font(.headline)
                                .foregroundStyle(trimmedName.isEmpty ? .tertiary : .primary)
                            Text("This is how others see you on recipes and in activity.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.vertical, 4)
                .listRowBackground(Color.clear)

                TextField("Display name", text: $displayName)
                    .textContentType(.name)
                    .textInputAutocapitalization(.words)

                Button {
                    showPhotoOptions = true
                } label: {
                    Label("Choose profile photo", systemImage: "photo.on.rectangle.angled")
                }

                Button {
                    Task { await saveProfile() }
                } label: {
                    HStack {
                        Spacer()
                        if savingProfile {
                            ProgressView()
                        } else {
                            Text("Save changes")
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canSaveProfile)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            } header: {
                Text("How you appear")
            } footer: {
                Text("Saving updates your public name and photo. You can change your name, your photo, or both in one tap.")
            }

            Section {
                SecureField("New password", text: $newPassword)
                    .textContentType(.newPassword)
                SecureField("Confirm password", text: $confirmPassword)
                    .textContentType(.newPassword)
                Button {
                    Task { await changePassword() }
                } label: {
                    if savingPassword {
                        ProgressView()
                    } else {
                        Text("Update password")
                    }
                }
                .disabled(savingPassword || !passwordFormValid)
            } header: {
                Text("Security")
            } footer: {
                Text("Use at least 6 characters.")
            }

            if let passwordMessage {
                Section {
                    Text(passwordMessage)
                        .font(.footnote)
                        .foregroundStyle(passwordMessage.contains("Updated") ? .green : .red)
                }
            }

            Section {
                Button("Sign out", role: .destructive) {
                    Task {
                        try? await supabase.signOut()
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadProfile() }
        .confirmationDialog("Profile photo", isPresented: $showPhotoOptions) {
            Button("Photo library") {
                pickerSource = .photoLibrary
                showPicker = true
            }
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take photo") {
                    pickerSource = .camera
                    showPicker = true
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showPicker) {
            ImagePicker(sourceType: pickerSource, selectedImage: $pickedAvatar, onComplete: nil)
        }
        .alert("Profile", isPresented: $showProfileAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(profileMessage ?? "")
        }
        .alert("Password updated", isPresented: $showPasswordSuccess) {
            Button("OK", role: .cancel) {}
        }
    }

    private var previewInitials: String {
        let t = trimmedName
        if !t.isEmpty {
            return String(t.prefix(2))
        }
        if let e = supabase.currentUser?.email {
            return String(e.prefix(2)).uppercased()
        }
        return "??"
    }

    private var passwordFormValid: Bool {
        newPassword.count >= 6 && newPassword == confirmPassword
    }

    private func loadProfile() async {
        guard let id = supabase.currentUserIdString else { return }
        await supabase.ensureProfileRowExists()
        if let p = try? await supabase.fetchProfile(by: id) {
            displayName = p.displayName ?? ""
            savedAvatarURL = p.avatarURL
        }
    }

    private func saveProfile() async {
        guard supabase.currentUserIdString != nil else { return }
        savingProfile = true
        defer { savingProfile = false }
        do {
            var newURL: String?
            if let img = pickedAvatar {
                guard let uid = supabase.currentUserIdString else { return }
                newURL = try await supabase.uploadAvatar(img, userId: uid)
            }
            let nameForPatch: String? = trimmedName.isEmpty ? nil : trimmedName
            try await supabase.updateProfile(
                displayName: nameForPatch,
                avatarURL: newURL
            )
            await loadProfile()
            pickedAvatar = nil
            avatarPreviewVersion += 1
            NotificationCenter.default.post(name: .miniRecipeProfileUpdated, object: nil)
            profileMessage = "Your profile was updated."
            showProfileAlert = true
        } catch {
            profileMessage = error.localizedDescription
            showProfileAlert = true
        }
    }

    private func changePassword() async {
        passwordMessage = nil
        savingPassword = true
        defer { savingPassword = false }
        do {
            try await supabase.updatePassword(newPassword)
            newPassword = ""
            confirmPassword = ""
            passwordMessage = "Updated. Use your new password next sign-in on other devices."
            showPasswordSuccess = true
        } catch {
            passwordMessage = error.localizedDescription
        }
    }
}
