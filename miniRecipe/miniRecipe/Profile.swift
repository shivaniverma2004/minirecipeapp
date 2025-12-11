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

    // MARK: - Computed helpers (optional but useful)

    var safeID: String {
        id ?? ""
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
