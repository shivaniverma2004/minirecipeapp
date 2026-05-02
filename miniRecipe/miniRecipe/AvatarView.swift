//
//  AvatarView.swift
//  miniRecipe
//

import SwiftUI

struct AvatarView: View {
    let urlString: String?
    let initials: String
    /// Bump after uploading a new photo so `AsyncImage` does not keep a stale cached bitmap.
    var imageVersion: Int = 0

    @ScaledMetric(wrappedValue: 40, relativeTo: .body) private var size: CGFloat

    init(urlString: String?, initials: String, size: CGFloat = 40, imageVersion: Int = 0) {
        self.urlString = urlString
        self.initials = initials
        self.imageVersion = imageVersion
        _size = ScaledMetric(wrappedValue: size, relativeTo: .body)
    }

    var body: some View {
        Group {
            let raw = urlString?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !raw.isEmpty {
                RemoteImage(urlString: urlString, version: imageVersion, contentMode: .fill)
            } else {
                initialsCircle
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Profile photo")
    }

    private var initialsCircle: some View {
        Circle()
            .fill(Color(uiColor: .tertiarySystemFill))
            .overlay {
                Text(initials.prefix(2).uppercased())
                    .font(.title3.weight(.semibold))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
            }
    }
}
