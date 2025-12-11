//
//  SupabaseManager.swift
//  miniRecipe
//
//  Created by Shivani Verma on 11/12/25.


import Foundation
import SwiftUI
import Combine
import Supabase
import UIKit

@MainActor
final class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    @Published var currentUser: User? = nil
    @Published var isSignedIn: Bool = false

    private init() {
        client = SupabaseClient(supabaseURL: Config.supabaseURL, supabaseKey: Config.supabaseAnonKey)
    }

    // MARK: - AUTH

    func signUp(email: String, password: String) async throws {
        let resp = try await client.auth.signUp(email: email, password: password)
        // resp.user may be non-optional in your SDK; assign directly
        self.currentUser = resp.user
        self.isSignedIn = (resp.user != nil)
    }

    func signIn(email: String, password: String) async throws {
        let resp = try await client.auth.signIn(email: email, password: password)
        self.currentUser = resp.user
        self.isSignedIn = (resp.user != nil)
    }

    func signOut() async throws {
        try await client.auth.signOut()
        self.currentUser = nil
        self.isSignedIn = false
    }

    // MARK: - RECIPES

    /// Fetch latest recipes. Uses resp.data (non-optional Data in your SDK).
    func fetchRecipes(limit: Int = 50) async throws -> [Recipe] {
        let resp = try await client
            .from("recipes")
            .select()
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()

        // Your SDK exposes resp.data (non-optional Data). Use it directly.
        let data: Data = resp.data

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode([Recipe].self, from: data)
    }

    
    func addRecipe(title: String, description: String? = nil, imageURL: String? = nil) async throws -> Recipe? {
        struct RecipeInsert: Encodable {
            let title: String
            let description: String?
            let image_url: String?
            let author_id: String
        }

        guard let user = currentUser else {
            throw NSError(domain: "No authenticated user", code: 401)
        }

        let payload = RecipeInsert(
            title: title,
            description: description,
            image_url: imageURL,
            author_id: String(describing: user.id)
        )

        // Important: .select() returns rows so we can decode Recipe
        let response = try await client
            .from("recipes")
            .insert(payload)
            .select()    // REQUIRED for decoding
            .single()    // Return only inserted row
            .execute()

        // Decode result safely for current SDK
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        return try decoder.decode(Recipe.self, from: response.data)
    }


    // MARK: - STORAGE (image upload)

    /// Upload UIImage to Supabase storage and return a public URL string.
    func uploadImage(_ image: UIImage, fileName: String, bucket: String = "recipe-images") async throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw NSError(domain: "SupabaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert UIImage to JPEG"])
        }

        // Upload - the SDK in your project expects labeled parameter names
        _ = try await client.storage.from(bucket).upload(path: fileName, file: data)

        // Try getPublicURL(path:)
        let publicURL = try client.storage.from(bucket).getPublicURL(path: fileName)
        // publicURL may be URL
        return publicURL.absoluteString
    }

    // MARK: - PROFILES

    func fetchProfile(by id: String) async throws -> Profile? {
        let resp = try await client
            .from("profiles")
            .select()
            .eq("id", value: id)
            .limit(1)
            .execute()

        let data: Data = resp.data
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let rows = try decoder.decode([Profile].self, from: data)
        return rows.first
    }
}
