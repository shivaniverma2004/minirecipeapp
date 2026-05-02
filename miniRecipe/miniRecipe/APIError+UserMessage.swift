//
//  APIError+UserMessage.swift
//  miniRecipe
//

import Foundation

enum UserFacingAPIError {
    /// Maps common Supabase / PostgREST failures to clearer copy; falls back to `localizedDescription`.
    static func message(for error: Error) -> String {
        let text = error.localizedDescription.lowercased()
        let full = error.localizedDescription

        if text.contains("row-level security")
            || text.contains("rls")
            || text.contains("permission denied")
            || text.contains("42501")
            || text.contains("insufficient privilege")
            || text.contains("not authorized")
            || text.contains("401")
            || text.contains("403") {
            return "You don’t have access to this data. Check Row Level Security policies for the recipes table in Supabase (e.g. allow read for anon or authenticated users)."
        }

        if text.contains("network") || text.contains("internet") || text.contains("timed out") {
            return "Network problem. Check your connection and try again.\n\n\(full)"
        }

        return full
    }
}
