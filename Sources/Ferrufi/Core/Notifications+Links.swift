//
//  Notifications+Links.swift
//  Ferrufi
//
//  Centralized Notification.Name extensions for link-related notifications.
//
//  Adds strongly-typed notification names used across the app for opening
//  wiki-style internal links and file:// links.
//
//  Created by assistant.
//

import Foundation

extension Notification.Name {
    /// Notification posted when the UI requests opening an internal wiki-style link.
    /// The `object` of the notification is expected to be a `String` containing the target note name.
    public static let openWikiLink = Notification.Name("Ferrufi.Notification.openWikiLink")

    /// Notification posted when the UI requests opening an external or internal file link.
    /// The `object` of the notification is expected to be a `URL`.
    public static let openFileLink = Notification.Name("Ferrufi.Notification.openFileLink")
}
