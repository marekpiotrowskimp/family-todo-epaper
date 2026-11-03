import Foundation

/// Tożsamość telefonu w rodzinie. Bez parowania: wystarczy `userId` i imię pokazywane na wyświetlaczu.
/// Dostęp do urządzenia daje wspólny klucz rodziny (`FamilyKey`, generowany przez tools/make-family-key.sh).
struct Identity: Equatable {
    var userId: String
    var displayName: String
}

enum IdentityStore {
    private static let userIdKey = "identity.userId"
    private static let nameKey = "identity.displayName"

    static func load() -> Identity? {
        let defaults = UserDefaults.standard
        guard let userId = defaults.string(forKey: userIdKey), let name = defaults.string(forKey: nameKey) else {
            return nil
        }
        return Identity(userId: userId, displayName: name)
    }

    static func create(displayName: String) -> Identity {
        let identity = Identity(userId: UUID().uuidString.lowercased(), displayName: displayName)
        UserDefaults.standard.set(identity.userId, forKey: userIdKey)
        UserDefaults.standard.set(identity.displayName, forKey: nameKey)
        return identity
    }
}
