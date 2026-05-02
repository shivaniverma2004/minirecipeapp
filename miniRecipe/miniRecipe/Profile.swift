//
//  Profile.swift
//  miniRecipe
//
//  Created by Shivani Verma on 11/12/25.
//

import Foundation

struct Profile: Codable, Identifiable {
    let id: String?
    let email: String?
    let displayName: String?
    let avatarURL: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let u = try? c.decode(UUID.self, forKey: .id) {
            id = u.uuidString.lowercased()
        } else if let s = try c.decodeIfPresent(String.self, forKey: .id) {
            id = s.lowercased()
        } else {
            id = nil
        }
        email = try c.decodeIfPresent(String.self, forKey: .email)
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName)
        if let raw = try c.decodeIfPresent(String.self, forKey: .avatarURL) {
            let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            avatarURL = t.isEmpty ? nil : t
        } else {
            avatarURL = nil
        }
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
    }

    init(id: String?, email: String?, displayName: String?, avatarURL: String?, createdAt: String?) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.createdAt = createdAt
    }

    var initials: String {
        if let name = displayName, !name.isEmpty {
            return name
                .split(separator: " ")
                .compactMap { $0.first?.uppercased() }
                .joined()
        }
        if let email = email {
            return String(email.prefix(2)).uppercased()
        }
        return "??"
    }
}
