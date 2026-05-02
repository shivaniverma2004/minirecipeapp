//
//  Recipe.swift
//  miniRecipe
//
//  Created by Shivani Verma on 11/12/25.
//

import SwiftUI

struct Recipe: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let description: String?
    let imageURL: String?
    let authorID: String?
    let likes: Int?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case imageURL = "image_url"
        case authorID = "author_id"
        case likes
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let u = try? c.decode(UUID.self, forKey: .id) {
            id = u.uuidString.lowercased()
        } else {
            let s = try c.decode(String.self, forKey: .id)
            id = s.lowercased()
        }
        title = try c.decode(String.self, forKey: .title)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        if let raw = try c.decodeIfPresent(String.self, forKey: .imageURL) {
            let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            imageURL = t.isEmpty ? nil : t
        } else {
            imageURL = nil
        }
        if let a = try? c.decode(UUID.self, forKey: .authorID) {
            authorID = a.uuidString.lowercased()
        } else if let s = try c.decodeIfPresent(String.self, forKey: .authorID) {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            authorID = t.isEmpty ? nil : t.lowercased()
        } else {
            authorID = nil
        }
        likes = try c.decodeIfPresent(Int.self, forKey: .likes)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
    }

    init(
        id: String,
        title: String,
        description: String?,
        imageURL: String?,
        authorID: String?,
        likes: Int?,
        createdAt: String?
    ) {
        self.id = id.lowercased()
        self.title = title
        self.description = description
        self.imageURL = imageURL
        self.authorID = authorID.map { $0.lowercased() }
        self.likes = likes
        self.createdAt = createdAt
    }
}

// MARK: - Row view
struct RecipeRow: View {
    let recipe: Recipe

    @EnvironmentObject private var supabase: SupabaseManager
    @State private var authorLabel: String?
    @ScaledMetric(relativeTo: .body) private var thumbnailSide: CGFloat = 76

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            thumbnail
                .frame(width: thumbnailSide, height: thumbnailSide)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(recipe.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .accessibilityLabel("\(recipe.title)")

                if let name = authorLabel, !name.isEmpty {
                    Label(name, systemImage: "person.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .labelStyle(.titleAndIcon)
                        .imageScale(.small)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                if let desc = recipe.description, !desc.isEmpty {
                    Text(desc)
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "hand.thumbsup.fill")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text("\(recipe.likes ?? 0)")
                        .font(.subheadline.weight(.medium))
                        .monospacedDigit()
                }
                .accessibilityLabel("\(recipe.likes ?? 0) likes")
                Text(relativeDateString(from: recipe.createdAt))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 6)
        .task(id: recipe.authorID ?? "") {
            await loadAuthorLabel()
        }
    }

    private func loadAuthorLabel() async {
        guard let aid = recipe.authorID, !aid.isEmpty else { return }
        do {
            guard let p = try await supabase.fetchProfile(by: aid) else {
                await MainActor.run { authorLabel = "Cook" }
                return
            }
            let trimmed = p.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let label = trimmed.isEmpty ? (p.email ?? "") : trimmed
            await MainActor.run { authorLabel = label.isEmpty ? "Cook" : label }
        } catch {
            await MainActor.run { authorLabel = "Cook" }
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let s = recipe.imageURL?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
            RemoteImage(urlString: recipe.imageURL, version: 0, contentMode: .fill)
        } else {
            ZStack {
                Color(uiColor: .tertiarySystemFill)
                Image(systemName: "fork.knife")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func relativeDateString(from isoString: String?) -> String {
        guard
            let iso = isoString,
            let date = ISO8601DateFormatter().date(from: iso)
        else { return "" }
        let df = RelativeDateTimeFormatter()
        df.unitsStyle = .short
        return df.localizedString(for: date, relativeTo: Date())
    }
}
