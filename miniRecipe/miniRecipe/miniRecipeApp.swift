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
                if supabase.isSignedIn {
                    ContentView()
                        .environmentObject(supabase)
                } else {
                    AuthView { success in
                        if success {
                            // AuthView dismissed and signed in — trigger view update
                            // SupabaseManager.isSignedIn will be set by signIn/signUp
                        }
                    }
                    .environmentObject(supabase)
                }
            }
            .onAppear {
                Task {
                    // Optionally try to restore session if you implement restoreSessionIfNeeded()
                    // await supabase.restoreSessionIfNeeded()
                }
            }
        }
    }
}
