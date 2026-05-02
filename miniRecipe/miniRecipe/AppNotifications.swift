//
//  AppNotifications.swift
//  miniRecipe
//

import Foundation

extension Notification.Name {
    static let miniRecipeProfileUpdated = Notification.Name("miniRecipeProfileUpdated")
    /// Posted after recipe create / delete / bulk change so lists can refresh.
    static let miniRecipeLibraryDidChange = Notification.Name("miniRecipeLibraryDidChange")
    /// Used to jump from deep-linked events to the Profile tab (native "me" behavior).
    static let miniRecipeOpenCurrentProfileTab = Notification.Name("miniRecipeOpenCurrentProfileTab")
}
