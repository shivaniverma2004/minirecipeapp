//
//  Recipe.swift
//  miniRecipe
//
//  Created by Shivani Verma on 11/12/25.
//

import SwiftUI

struct Recipe: Identifiable, Codable {
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
}

// MARK: - Row view
struct RecipeRow: View {
    let recipe: Recipe

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
                .frame(width: 72, height: 72)
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 6) {
                Text(recipe.title)
                    .font(.headline)
                    .lineLimit(1)
                    .accessibilityLabel("\(recipe.title)")

                if let desc = recipe.description, !desc.isEmpty {
                    Text(desc)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                } else {
                    Text("No description")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text("\(recipe.likes ?? 0)")
                    .font(.subheadline)
                    .accessibilityLabel("\(recipe.likes ?? 0) likes")
                Text(relativeDateString(from: recipe.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let urlString = recipe.imageURL, let url = URL(string: urlString) {
            // AsyncImage requires iOS 15+
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ZStack {
                        Color(white: 0.95)
                        ProgressView()
                    }
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    ZStack {
                        Color(white: 0.95)
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                @unknown default:
                    Color(white: 0.95)
                }
            }
            .clipped()
        } else {
            ZStack {
                Color(white: 0.95)
                Image(systemName: "fork.knife")
                    .font(.title)
                    .foregroundColor(.secondary)
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

#if DEBUG
struct RecipeRow_Previews: PreviewProvider {
    static var sample = Recipe(
        id: UUID().uuidString,
        title: "Masala Pasta",
        description: "A quick and spicy pasta recipe with Indian masala.",
        imageURL: nil,
        authorID: nil,
        likes: 12,
        createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-60*60*24))
    )

    static var previews: some View {
        Group {
            RecipeRow(recipe: sample)
                .previewLayout(.sizeThatFits)
                .padding()
            RecipeRow(recipe: Recipe(
                id: UUID().uuidString,
                title: "Photo recipe",
                description: "Has image",
                imageURL: "https://picsum.photos/200",
                authorID: nil,
                likes: 5,
                createdAt: ISO8601DateFormatter().string(from: Date())
            ))
                .previewLayout(.sizeThatFits)
                .padding()
        }
    }
}
#endif
