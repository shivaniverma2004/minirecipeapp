//
//  miniRecipeApp.swift
//  miniRecipe
//
//  Created by Shivani Verma on 11/12/25.
//

import SwiftUI

@main
struct miniRecipeApp: App {
    @StateObject private var supabase = SupabaseManager.shared

    var body: some Scene {
        WindowGroup {
            Group {
                switch supabase.authState {
                case .restoring:
                    ProgressView("Loading…")
                        .controlSize(.large)
                        .accessibilityLabel("Restoring your session")
                case .signedOut:
                    AuthView(showsDismissButton: false, onComplete: { _ in })
                case .signedIn:
                    MainTabView()
                }
            }
            .environmentObject(supabase)
            .task {
                await supabase.restoreSession()
            }
        }
    }
}
