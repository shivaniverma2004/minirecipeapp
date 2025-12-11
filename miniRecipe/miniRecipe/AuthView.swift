//
//  AuthView.swift
//  miniRecipe
//
//  Created by Shivani Verma on 11/12/25.


import SwiftUI

struct AuthView: View {
    enum Mode {
        case signIn, signUp
    }

    @Environment(\.dismiss) private var dismiss

    @State private var mode: Mode = .signIn
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var displayName: String = ""

    @State private var showPassword: Bool = false
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    /// Called with `true` on successful auth (so callers can refresh and dismiss)
    var onComplete: ((Bool) -> Void)? = nil

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(mode == .signIn ? "Sign in to your account" : "Create a new account")) {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
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

                    Toggle(isOn: $showPassword) {
                        Text("Show password")
                            .font(.footnote)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))

                    if mode == .signUp {
                        SecureField("Confirm password", text: $confirmPassword)
                            .textContentType(.newPassword)
                        TextField("Display name (optional)", text: $displayName)
                            .autocapitalization(.words)
                    }
                }

                if let err = errorMessage {
                    Section {
                        Text(err)
                            .foregroundColor(.red)
                            .font(.footnote)
                            .lineLimit(nil)
                    }
                }

                Section {
                    Button(action: { Task { await submit() } }) {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                            } else {
                                Text(mode == .signIn ? "Sign In" : "Create account")
                                    .bold()
                            }
                            Spacer()
                        }
                    }
                    .disabled(isLoading || !isFormValid)
                }

                Section {
                    if mode == .signIn {
                        Button("Switch to Sign Up") {
                            withAnimation { mode = .signUp; clearErrors() }
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button("Already have an account? Sign In") {
                            withAnimation { mode = .signIn; clearErrors() }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .navigationTitle(mode == .signIn ? "Sign In" : "Sign Up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .disabled(isLoading)
            .onAppear { /* nothing for now */ }
        }
    }

    // MARK: - Validation
    private var isFormValid: Bool {
        isValidEmail(email) &&
        !password.isEmpty &&
        (mode == .signIn ? true : password.count >= 6 && password == confirmPassword)
    }

    private func clearErrors() {
        errorMessage = nil
    }

    // MARK: - Actions
    private func submit() async {
        await MainActor.run { clearErrors(); isLoading = true }
        defer { Task { await MainActor.run { isLoading = false } } }

        do {
            switch mode {
            case .signIn:
                try await SupabaseManager.shared.signIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                                                        password: password)
                await MainActor.run {
                    onComplete?(true)
                    dismiss()
                }

            case .signUp:
                try await SupabaseManager.shared.signUp(email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                                                        password: password)

                // If you want to save displayName into profiles immediately, we can add that call here.
                await MainActor.run {
                    onComplete?(true)
                    dismiss()
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "Auth failed: \(error.localizedDescription)"
                onComplete?(false)
            }
            print("AuthView error:", error)
        }
    }

    // MARK: - Utilities
    private func isValidEmail(_ str: String) -> Bool {
        let s = str.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return false }
        // Lightweight regex for email validation
        let pattern = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return s.range(of: pattern, options: .regularExpression) != nil
    }
}

#if DEBUG
struct AuthView_Previews: PreviewProvider {
    static var previews: some View {
        AuthView { success in
            print("Auth complete: \(success)")
        }
    }
}
#endif
