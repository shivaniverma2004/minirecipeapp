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
    @State private var avatarPreviewVersion = 0
    @State private var initialDisplayName = ""
    @State private var isLoaded = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case displayName
        case newPassword
        case confirmPassword
    }

    private var trimmedName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSaveProfile: Bool {
        if savingProfile { return false }
        if !isLoaded { return false }
        if pickedAvatar != nil { return true }
        return trimmedName != initialDisplayName
    }

    var body: some View {
        Form {
            Section {
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
                        Text("Shown on your recipes, likes, and notifications.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 4)
                .listRowBackground(Color.clear)

                TextField("Display name", text: $displayName)
                    .textContentType(.name)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled(true)
                    .focused($focusedField, equals: .displayName)
                    .submitLabel(.done)

                Button {
                    showPhotoOptions = true
                } label: {
                    Label("Choose profile photo", systemImage: "photo.on.rectangle.angled")
                }
                .foregroundStyle(.primary)

                if let profileMessage, !profileMessage.isEmpty {
                    Label(profileMessage, systemImage: profileMessage.contains("updated") ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(profileMessage.contains("updated") ? .green : .red)
                        .fixedSize(horizontal: false, vertical: true)
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
                Text("Public profile")
            } footer: {
                Text("You can update name and photo together. Changes appear immediately across the app.")
            }

            Section {
                SecureField("New password", text: $newPassword)
                    .textContentType(.newPassword)
                    .focused($focusedField, equals: .newPassword)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .confirmPassword }
                SecureField("Confirm password", text: $confirmPassword)
                    .textContentType(.newPassword)
                    .focused($focusedField, equals: .confirmPassword)
                    .submitLabel(.go)
                    .onSubmit { Task { await changePassword() } }

                if !confirmPassword.isEmpty, confirmPassword != newPassword {
                    Label("Passwords do not match.", systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button {
                    Task { await changePassword() }
                } label: {
                    HStack {
                        Spacer()
                        if savingPassword {
                            ProgressView()
                        } else {
                            Text("Update password")
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(savingPassword || !passwordFormValid)
            } header: {
                Text("Security")
            } footer: {
                Text("Use at least 6 characters and keep it unique.")
            }

            if let passwordMessage {
                Section {
                    Label(passwordMessage, systemImage: passwordMessage.contains("Updated") ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
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
        .navigationBarTitleDisplayMode(.large)
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
        .alert("Password updated", isPresented: $showPasswordSuccess) {
            Button("OK", role: .cancel) {}
        }
        .scrollDismissesKeyboard(.interactively)
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
            initialDisplayName = (p.displayName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            savedAvatarURL = p.avatarURL
            isLoaded = true
        } else {
            isLoaded = true
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
            initialDisplayName = trimmedName
        } catch {
            profileMessage = error.localizedDescription
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
