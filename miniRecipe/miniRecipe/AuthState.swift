//
//  AuthState.swift
//  miniRecipe
//

import Foundation

enum AuthState: Equatable {
    case restoring
    case signedOut
    case signedIn
}

enum SignUpOutcome: Equatable {
    /// Session created; user is signed in.
    case signedIn
    /// Account created but email confirmation is required (no session yet).
    case confirmationRequired
}
