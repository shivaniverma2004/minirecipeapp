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
                            
                        }
                    }
                    .environmentObject(supabase)
                }
            }
            .onAppear {
                Task {
                    
                }
            }
        }
    }
}
