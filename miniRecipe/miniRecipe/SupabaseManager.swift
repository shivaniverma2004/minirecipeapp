//
//  SupabaseManager.swift
//  miniRecipe
//

import Foundation
import SwiftUI
import Combine
import Supabase
import UIKit

@MainActor
final class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()

    /// Decodes PostgREST JSON. **Do not** use `convertFromSnakeCase` here — `Recipe`, `Profile`, etc.
    /// already map snake_case in `CodingKeys`; mixing both breaks decoding (`author_id`, `image_url` become nil).
    private static func postgresDecoder() -> JSONDecoder {
        JSONDecoder()
    }

    let client: SupabaseClient

    @Published var currentUser: User? = nil
    @Published var isSignedIn: Bool = false
    @Published private(set) var authState: AuthState = .restoring
    @Published private(set) var unreadNotificationCount: Int = 0
    /// Set from Profile (etc.) so any tab can present sign-in without local sheets everywhere.
    @Published var globalAuthSheetPresented = false

    private init() {
        client = SupabaseClient(
            supabaseURL: Config.supabaseURL,
            supabaseKey: Config.supabaseAnonKey,
            options: SupabaseClientOptions(
                auth: SupabaseClientOptions.AuthOptions(
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }

    /// Lowercased so it matches Postgres `auth.uid()::text` and RLS on text columns (e.g. `recipes.author_id`).
    var currentUserIdString: String? {
        currentUser?.id.uuidString.lowercased()
    }

    func restoreSession() async {
        do {
            let session = try await client.auth.session
            let activeSession = session.isExpired
                ? try await client.auth.refreshSession()
                : session
            currentUser = activeSession.user
            isSignedIn = true
            authState = .signedIn
            await ensureProfileRowExists()
            await refreshUnreadNotificationCount()
        } catch {
            currentUser = nil
            isSignedIn = false
            authState = .signedOut
            unreadNotificationCount = 0
        }
    }

    // MARK: - Auth

    func signUp(email: String, password: String, displayName: String? = nil) async throws -> SignUpOutcome {
        let meta: [String: AnyJSON]? = {
            guard let t = displayName?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else {
                return nil
            }
            return ["display_name": .string(t)]
        }()
        let resp = try await client.auth.signUp(email: email, password: password, data: meta)
        if let session = resp.session {
            currentUser = session.user
            isSignedIn = true
            authState = .signedIn
            await ensureProfileRowExists()
            await refreshUnreadNotificationCount()
            return .signedIn
        }
        currentUser = resp.user
        isSignedIn = false
        authState = .signedOut
        return .confirmationRequired
    }

    func signIn(email: String, password: String) async throws {
        let resp = try await client.auth.signIn(email: email, password: password)
        currentUser = resp.user
        isSignedIn = true
        authState = .signedIn
        await ensureProfileRowExists()
        await refreshUnreadNotificationCount()
    }

    func signOut() async throws {
        try await client.auth.signOut()
        self.currentUser = nil
        self.isSignedIn = false
        self.authState = .signedOut
        self.unreadNotificationCount = 0
    }

    func updatePassword(_ newPassword: String) async throws {
        _ = try await client.auth.update(user: UserAttributes(password: newPassword))
    }

    // MARK: - Recipes

    func fetchRecipes(limit: Int = 50) async throws -> [Recipe] {
        let resp = try await client
            .from("recipes")
            .select()
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()

        let decoder = Self.postgresDecoder()
        return try decoder.decode([Recipe].self, from: resp.data)
    }

    func fetchRecipe(id: String) async throws -> Recipe {
        let rid = id.lowercased()
        let resp = try await client
            .from("recipes")
            .select()
            .eq("id", value: rid)
            .single()
            .execute()
        let decoder = Self.postgresDecoder()
        return try decoder.decode(Recipe.self, from: resp.data)
    }

    func fetchRecipes(byAuthorId authorId: String, limit: Int = 100) async throws -> [Recipe] {
        let resp = try await client
            .from("recipes")
            .select()
            .eq("author_id", value: authorId.lowercased())
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()

        let decoder = Self.postgresDecoder()
        return try decoder.decode([Recipe].self, from: resp.data)
    }

    func addRecipe(title: String, description: String? = nil, imageURL: String? = nil) async throws -> Recipe {
        struct RecipeInsert: Encodable {
            let title: String
            let description: String?
            let image_url: String?
            let author_id: String
        }

        guard let user = currentUser else {
            throw NSError(domain: "miniRecipe", code: 401, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }

        let aid = user.id.uuidString.lowercased()
        let payload = RecipeInsert(
            title: title,
            description: description,
            image_url: imageURL,
            author_id: aid
        )

        let response = try await client
            .from("recipes")
            .insert(payload)
            .select()
            .single()
            .execute()

        let decoder = Self.postgresDecoder()
        return try decoder.decode(Recipe.self, from: response.data)
    }

    struct RecipeUpdate: Encodable {
        let title: String
        let description: String?
        let image_url: String?
    }

    func updateRecipe(id: String, title: String, description: String?, imageURL: String?) async throws {
        let patch = RecipeUpdate(title: title, description: description, image_url: imageURL)
        let rid = id.lowercased()
        _ = try await client
            .from("recipes")
            .update(patch)
            .eq("id", value: rid)
            .execute()
    }

    func deleteRecipe(id: String) async throws {
        let rid = id.lowercased()
        _ = try await client
            .from("recipes")
            .delete()
            .eq("id", value: rid)
            .execute()
    }

    struct SetRecipeLikesParams: Encodable {
        let p_recipe_id: String
        let p_likes: Int
    }

    /// Uses `set_recipe_likes` RPC (see `supabase/schema.sql`). Falls back to direct update if RPC missing.
    func setRecipeLikes(recipeId: String, likes: Int) async throws {
        let rid = recipeId.lowercased()
        do {
            _ = try await client
                .rpc("set_recipe_likes", params: SetRecipeLikesParams(p_recipe_id: rid, p_likes: likes))
                .execute()
        } catch {
            struct LikesPatch: Encodable { let likes: Int }
            _ = try await client
                .from("recipes")
                .update(LikesPatch(likes: likes))
                .eq("id", value: rid)
                .execute()
        }
    }

    // MARK: - Notifications

    struct NotificationInsert: Encodable {
        let user_id: String
        let actor_id: String
        let type: String
        let title: String
        let body: String?
        let recipe_id: String?
    }

    func insertNotification(_ row: NotificationInsert) async throws {
        let normalized = NotificationInsert(
            user_id: row.user_id.lowercased(),
            actor_id: row.actor_id.lowercased(),
            type: row.type,
            title: row.title,
            body: row.body,
            recipe_id: row.recipe_id.map { $0.lowercased() }
        )
        _ = try await client
            .from("notifications")
            .insert(normalized)
            .execute()
    }

    func fetchNotifications(limit: Int = 50) async throws -> [AppNotification] {
        let resp = try await client
            .from("notifications")
            .select()
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()

        let decoder = Self.postgresDecoder()
        return try decoder.decode([AppNotification].self, from: resp.data)
    }

    func markNotificationRead(id: String) async throws {
        struct Patch: Encodable {
            let read_at: String
        }
        let iso = ISO8601DateFormatter().string(from: Date())
        _ = try await client
            .from("notifications")
            .update(Patch(read_at: iso))
            .eq("id", value: id)
            .execute()
        await refreshUnreadNotificationCount()
    }

    func markAllNotificationsRead() async throws {
        let items = try await fetchNotifications(limit: 200)
        for n in items where n.isUnread {
            try? await markNotificationRead(id: n.id)
        }
    }

    func refreshUnreadNotificationCount() async {
        guard isSignedIn else {
            unreadNotificationCount = 0
            return
        }
        do {
            let resp = try await client
                .from("notifications")
                .select("id", head: true, count: .exact)
                .filter("read_at", operator: "is", value: "null")
                .execute()
            unreadNotificationCount = resp.count ?? 0
        } catch {
            unreadNotificationCount = 0
        }
    }

    // MARK: - Follows

    func follow(userId: String) async throws {
        let other = userId.lowercased()
        guard let me = currentUserIdString, me != other else { return }
        struct Row: Encodable {
            let follower_id: String
            let following_id: String
        }
        _ = try await client
            .from("follows")
            .insert(Row(follower_id: me, following_id: other))
            .execute()
    }

    func unfollow(userId: String) async throws {
        guard let me = currentUserIdString else { return }
        let other = userId.lowercased()
        _ = try await client
            .from("follows")
            .delete()
            .eq("follower_id", value: me)
            .eq("following_id", value: other)
            .execute()
    }

    func isFollowing(userId: String) async throws -> Bool {
        guard let me = currentUserIdString else { return false }
        let other = userId.lowercased()
        let r = try await client
            .from("follows")
            .select("follower_id", head: true, count: .exact)
            .eq("follower_id", value: me)
            .eq("following_id", value: other)
            .execute()
        return (r.count ?? 0) > 0
    }

    func followerCount(userId: String) async throws -> Int {
        let uid = userId.lowercased()
        let r = try await client
            .from("follows")
            .select("follower_id", head: true, count: .exact)
            .eq("following_id", value: uid)
            .execute()
        return r.count ?? 0
    }

    func followingCount(userId: String) async throws -> Int {
        let uid = userId.lowercased()
        let r = try await client
            .from("follows")
            .select("following_id", head: true, count: .exact)
            .eq("follower_id", value: uid)
            .execute()
        return r.count ?? 0
    }

    // MARK: - Profiles

    func fetchProfile(by id: String) async throws -> Profile? {
        let resp = try await client
            .from("profiles")
            .select()
            .eq("id", value: id.lowercased())
            .limit(1)
            .execute()

        let decoder = Self.postgresDecoder()
        let rows = try decoder.decode([Profile].self, from: resp.data)
        return rows.first
    }

    private struct ProfilePatchEnc: Encodable {
        var display_name: String?
        var avatar_url: String?

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            if let d = display_name { try c.encode(d, forKey: .display_name) }
            if let a = avatar_url { try c.encode(a, forKey: .avatar_url) }
        }

        enum CodingKeys: String, CodingKey {
            case display_name
            case avatar_url
        }
    }

    func updateProfile(displayName: String?, avatarURL: String?) async throws {
        guard let uid = currentUserIdString else {
            throw NSError(domain: "miniRecipe", code: 401, userInfo: [NSLocalizedDescriptionKey: "Sign in to update your profile."])
        }
        let hasPatch = displayName != nil || avatarURL != nil
        guard hasPatch else {
            throw NSError(domain: "miniRecipe", code: -2, userInfo: [NSLocalizedDescriptionKey: "Nothing to save."])
        }
        await ensureProfileRowExists()
        let patch = ProfilePatchEnc(display_name: displayName, avatar_url: avatarURL)
        _ = try await client
            .from("profiles")
            .update(patch)
            .eq("id", value: uid)
            .execute()
    }

    func requestGlobalSignIn() {
        globalAuthSheetPresented = true
    }

    /// Ensures a `profiles` row exists (signup trigger can miss older accounts or failed runs).
    func ensureProfileRowExists() async {
        guard let uid = currentUserIdString else { return }
        if (try? await fetchProfile(by: uid)) != nil { return }
        struct Row: Encodable {
            let id: String
            let email: String?
        }
        let email = currentUser?.email
        do {
            try await client
                .from("profiles")
                .insert(Row(id: uid, email: email))
                .execute()
        } catch {
            // Row may already exist (race with trigger) or RLS; ignore.
        }
    }

    // MARK: - Storage

    func uploadRecipeImage(_ image: UIImage, fileName: String, bucket: String = "recipe-images") async throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.88) else {
            throw NSError(domain: "miniRecipe", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not encode image"])
        }
        let options = FileOptions(
            cacheControl: "3600",
            contentType: "image/jpeg",
            upsert: true
        )
        _ = try await client.storage.from(bucket).upload(fileName, data: data, options: options)
        let publicURL = try client.storage.from(bucket).getPublicURL(path: fileName)
        return publicURL.absoluteString
    }

    func uploadAvatar(_ image: UIImage, userId: String) async throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.88) else {
            throw NSError(domain: "miniRecipe", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not encode image"])
        }
        let path = "\(userId.lowercased()).jpg"
        let options = FileOptions(contentType: "image/jpeg", upsert: true)
        _ = try await client.storage.from("avatars").upload(path, data: data, options: options)
        let publicURL = try client.storage.from("avatars").getPublicURL(path: path)
        return publicURL.absoluteString
    }
}
