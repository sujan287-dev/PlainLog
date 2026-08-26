import Foundation

protocol BookmarkStore {
    func loadBookmarkData() -> Data?
    func saveBookmarkData(_ data: Data)
    func clearBookmarkData()
}

final class UserDefaultsBookmarkStore: BookmarkStore {
    private let key = "plainlog.folder.bookmark.data"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadBookmarkData() -> Data? {
        defaults.data(forKey: key)
    }

    func saveBookmarkData(_ data: Data) {
        defaults.set(data, forKey: key)
    }

    func clearBookmarkData() {
        defaults.removeObject(forKey: key)
    }
}
