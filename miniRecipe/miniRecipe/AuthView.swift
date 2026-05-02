//
//  AuthView.swift
//  miniRecipe
//

import SwiftUI

struct AuthView: View {
    enum Mode {
        case signIn, signUp
    }

    @Environment(\.dismiss) private var dismiss

    /// Hide when `AuthView` is the root screen (no presenting container to dismiss).
    var showsDismissButton: Bool = true

    @State private var mode: Mode = .signIn
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var displayName: String = ""

    @State private var showPassword: Bool = false
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var emailConfirmationMessage: String?

    var onComplete: ((Bool) -> Void)? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .textContentType(.emailAddress)
                        .accessibilityLabel("Email")
                        .submitLabel(.next)

                    Group {
                        if showPassword {
                            TextField("Password", text: $password)
                                .textContentType(mode == .signIn ? .password : .newPassword)
                                .accessibilityLabel("Password")
                        } else {
                            SecureField("Password", text: $password)
                                .textContentType(mode == .signIn ? .password : .newPassword)
                                .accessibilityLabel("Password")
                        }
                    }
                    .submitLabel(.done)

                    Toggle("Show password", isOn: $showPassword)

                    if mode == .signUp {
                        SecureField("Confirm password", text: $confirmPassword)
                            .textContentType(.newPassword)
                        TextField("Display name (optional)", text: $displayName)
                            .textContentType(.name)
                            .textInputAutocapitalization(.words)
                    }
                } header: {
                    Text(mode == .signIn ? "Sign in" : "Create account")
                } footer: {
                    Text(mode == .signIn ? "Use the email and password for your account." : "Choose a password of at least 6 characters.")
                }

                if let pending = emailConfirmationMessage {
                    Section {
                        Text(pending)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } header: {
                        Text("Check your email")
                    }
                }

                if let err = errorMessage {
                    Section {
                        Text(err)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Section {
                    Button {
                        Task { await submit() }
                    } label: {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                            } else {
                                Text(mode == .signIn ? "Sign In" : "Create account")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isLoading || !isFormValid)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                Section {
                    if mode == .signIn {
                        Button("Create an account") {
                            withAnimation { mode = .signUp; clearErrors() }
                        }
                    } else {
                        Button("Already have an account? Sign in") {
                            withAnimation { mode = .signIn; clearErrors() }
                        }
                    }
                }
            }
            .navigationTitle(mode == .signIn ? "Welcome back" : "Join miniRecipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showsDismissButton {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                }
            }
            .disabled(isLoading)
        }
    }

    private var isFormValid: Bool {
        isValidEmail(email) &&
            !password.isEmpty &&
            (mode == .signIn ? true : password.count >= 6 && password == confirmPassword)
    }

    private func clearErrors() {
        errorMessage = nil
        emailConfirmationMessage = nil
    }

    private func submit() async {
        await MainActor.run { clearErrors(); isLoading = true }
        defer { Task { await MainActor.run { isLoading = false } } }

        do {
            switch mode {
            case .signIn:
                try await SupabaseManager.shared.signIn(
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: password
                )
                await MainActor.run {
                    onComplete?(true)
                    dismiss()
                }

            case .signUp:
                let outcome = try await SupabaseManager.shared.signUp(
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: password,
                    displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                await MainActor.run {
                    switch outcome {
                    case .signedIn:
                        onComplete?(true)
                        dismiss()
                    case .confirmationRequired:
                        emailConfirmationMessage =
                            "We sent a confirmation link to your email. Open it to finish signing up, then return here and sign in."
                        onComplete?(false)
                    }
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                onComplete?(false)
            }
            AppLog.auth("sign-in/up failed: \(error.localizedDescription)")
        }
    }

    private func isValidEmail(_ str: String) -> Bool {
        let s = str.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return false }
        let pattern = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return s.range(of: pattern, options: .regularExpression) != nil
    }
}

#if DEBUG
#Preview("Auth") {
    AuthView { _ in }
}
#endif
