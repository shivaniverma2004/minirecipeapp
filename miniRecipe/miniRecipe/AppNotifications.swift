//
//  AppNotifications.swift
//  miniRecipe
//

import Foundation

extension Notification.Name {
    static let miniRecipeProfileUpdated = Notification.Name("miniRecipeProfileUpdated")
    /// Posted after recipe create / delete / bulk change so lists can refresh.
    static let miniRecipeLibraryDidChange = Notification.Name("miniRecipeLibraryDidChange")
}
