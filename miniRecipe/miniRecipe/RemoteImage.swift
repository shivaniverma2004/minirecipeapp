//
//  RemoteImage.swift
//  miniRecipe
//
//  Loads public HTTP(S) images via URLSession (more reliable than AsyncImage for Supabase Storage URLs).
//

import SwiftUI
import UIKit

struct RemoteImage: View {
    let urlString: String?
    /// Append `?v=` for cache busting after uploads.
    var version: Int = 0
    var contentMode: ContentMode = .fill

    @State private var image: UIImage?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if isLoading {
                Color(uiColor: .tertiarySystemFill)
                    .overlay { ProgressView() }
            } else {
                Color(uiColor: .tertiarySystemFill)
            }
        }
        .task(id: taskIdentity) {
            await load()
        }
    }

    private var taskIdentity: String {
        let base = urlString?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return "\(base)|\(version)"
    }

    private func load() async {
        await MainActor.run {
            image = nil
            isLoading = true
        }
        guard var s = urlString?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else {
            await MainActor.run { isLoading = false }
            return
        }
        if version > 0, var comp = URLComponents(string: s) {
            var q = comp.queryItems ?? []
            q.append(URLQueryItem(name: "v", value: "\(version)"))
            comp.queryItems = q
            if let u = comp.url { s = u.absoluteString }
        }
        guard let url = URL(string: s) else {
            await MainActor.run { isLoading = false }
            return
        }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                await MainActor.run { isLoading = false }
                return
            }
            let ui = UIImage(data: data)
            await MainActor.run {
                image = ui
                isLoading = false
            }
        } catch {
            await MainActor.run {
                image = nil
                isLoading = false
            }
        }
    }
}
