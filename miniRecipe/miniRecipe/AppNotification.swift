//
//  AppNotification.swift
//  miniRecipe
//

import Foundation

struct AppNotification: Identifiable, Codable, Hashable {
    let id: String
    let userId: String
    let actorId: String?
    let type: String
    let title: String
    let body: String?
    let recipeId: String?
    let readAt: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case actorId = "actor_id"
        case type
        case title
        case body
        case recipeId = "recipe_id"
        case readAt = "read_at"
        case createdAt = "created_at"
    }

    var isUnread: Bool { readAt == nil || readAt!.isEmpty }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let u = try? c.decode(UUID.self, forKey: .id) {
            id = u.uuidString
        } else {
            id = try c.decode(String.self, forKey: .id)
        }
        if let u = try? c.decode(UUID.self, forKey: .userId) {
            userId = u.uuidString
        } else {
            userId = try c.decode(String.self, forKey: .userId)
        }
        if let u = try c.decodeIfPresent(UUID.self, forKey: .actorId) {
            actorId = u.uuidString
        } else {
            actorId = try c.decodeIfPresent(String.self, forKey: .actorId)
        }
        type = try c.decode(String.self, forKey: .type)
        title = try c.decode(String.self, forKey: .title)
        body = try c.decodeIfPresent(String.self, forKey: .body)
        if let u = try c.decodeIfPresent(UUID.self, forKey: .recipeId) {
            recipeId = u.uuidString
        } else {
            recipeId = try c.decodeIfPresent(String.self, forKey: .recipeId)
        }
        readAt = try c.decodeIfPresent(String.self, forKey: .readAt)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
    }
}
