//
//  Config.swift
//  miniRecipe
//
//  Created by Shivani Verma on 11/12/25.
//

import Foundation

enum Config {

    /// From `Secrets.xcconfig` / target Info (`INFOPLIST_KEY_SUPABASE_*`). Release builds require these; DEBUG falls back for local convenience.
    static var supabaseURL: URL {
        if let s = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = URL(string: t), !t.isEmpty { return url }
        }
        #if DEBUG
        // Matches current dev project if Info keys from xcconfig fail to merge.
        return URL(string: "https://fijdbnjplynkzisxepiz.supabase.co")!
        #else
        fatalError("SUPABASE_URL not configured. Add Secrets.xcconfig per README.")
        #endif
    }

    static var supabaseAnonKey: String {
        if let s = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { return t }
        }
        #if DEBUG
        return """
        eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZpamRibmpwbHlua3ppc3hlcGl6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3MDc0MjksImV4cCI6MjA5MzI4MzQyOX0.4Q6GcVYi7iibNyZAd6ujY9o3oed9rhVDhhgWAKtevUM
        """
        #else
        fatalError("SUPABASE_ANON_KEY not configured. Add Secrets.xcconfig per README.")
        #endif
    }
}
