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
    @FocusState private var focusedField: Field?

    var onComplete: ((Bool) -> Void)? = nil

    private enum Field {
        case email
        case password
        case confirmPassword
        case displayName
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 8) {
                        Text(mode == .signIn ? "Welcome back" : "Create Account")
                            .font(.largeTitle.weight(.bold))
                        Text(mode == .signIn ? "Read. Cook. Share." : "Start your miniRecipe journey")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 40)

                    VStack(spacing: 14) {
                        if mode == .signUp {
                            authField("Full name", text: $displayName)
                                .textContentType(.name)
                                .textInputAutocapitalization(.words)
                                .focused($focusedField, equals: .displayName)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .email }
                        }

                        authField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .textContentType(.emailAddress)
                            .focused($focusedField, equals: .email)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .password }

                        passwordField("Password", text: $password, focused: .password)

                        if mode == .signUp {
                            passwordField("Confirm password", text: $confirmPassword, focused: .confirmPassword)
                        }

                        Button {
                            Task { await submit() }
                        } label: {
                            HStack {
                                Spacer()
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(mode == .signIn ? "Log In" : "Create Account")
                                        .font(.headline.weight(.semibold))
                                }
                                Spacer()
                            }
                            .padding(.vertical, 16)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .disabled(isLoading || !isFormValid)
                        .opacity((isLoading || !isFormValid) ? 0.6 : 1.0)
                    }
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color(uiColor: .secondarySystemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.black.opacity(0.03), lineWidth: 1)
                    )

                    if let pending = emailConfirmationMessage {
                        Text(pending)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }

                    if let err = errorMessage {
                        Label(err, systemImage: "exclamationmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }

                    if mode == .signIn {
                        Button("Don’t have an account? Sign up") {
                            withAnimation(.easeInOut(duration: 0.18)) { mode = .signUp }
                            clearErrors()
                        }
                        .font(.headline)
                    } else {
                        Button("Already have an account? Log in") {
                            withAnimation(.easeInOut(duration: 0.18)) { mode = .signIn }
                            clearErrors()
                        }
                        .font(.headline)
                    }

                    if showsDismissButton {
                        Button("Skip for now") { dismiss() }
                            .font(.headline.weight(.semibold))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                if showsDismissButton {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                    }
                }
            }
            .disabled(isLoading)
            .onChange(of: mode) { _, _ in
                confirmPassword = ""
                focusedField = nil
            }
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

    private func authField(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func passwordField(_ title: String, text: Binding<String>, focused: Field) -> some View {
        HStack(spacing: 8) {
            Group {
                if showPassword {
                    TextField(title, text: text)
                } else {
                    SecureField(title, text: text)
                }
            }
            .textContentType(.password)
            .focused($focusedField, equals: focused)
            .submitLabel(mode == .signUp && focused != .confirmPassword ? .next : .go)
            .onSubmit {
                switch focused {
                case .password:
                    if mode == .signUp {
                        focusedField = .confirmPassword
                    } else {
                        Task { await submit() }
                    }
                case .confirmPassword:
                    Task { await submit() }
                default:
                    break
                }
            }

            Button {
                showPassword.toggle()
            } label: {
                Image(systemName: showPassword ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel(showPassword ? "Hide password" : "Show password")
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
