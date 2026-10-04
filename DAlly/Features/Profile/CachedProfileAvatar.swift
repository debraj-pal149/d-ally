import Foundation
import SwiftUI
import UIKit

/// Keeps the signed-in profile photo on disk so Profile does not flash a placeholder
/// every time the tab is opened.
enum ProfileAvatarCache {
    private static let memory = NSCache<NSString, UIImage>()
    private static let folderName = "ProfileAvatars"

    static func image(for url: URL) -> UIImage? {
        let key = cacheKey(for: url)
        if let cached = memory.object(forKey: key as NSString) {
            return cached
        }
        let file = fileURL(for: key)
        guard let data = try? Data(contentsOf: file),
              let image = UIImage(data: data) else { return nil }
        memory.setObject(image, forKey: key as NSString)
        return image
    }

    static func store(_ image: UIImage, for url: URL) {
        let key = cacheKey(for: url)
        memory.setObject(image, forKey: key as NSString)
        guard let data = image.jpegData(compressionQuality: 0.9) else { return }
        let dir = cacheDirectory()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? data.write(to: fileURL(for: key), options: .atomic)
    }

    static func clearAll() {
        memory.removeAllObjects()
        let dir = cacheDirectory()
        try? FileManager.default.removeItem(at: dir)
    }

    private static func cacheKey(for url: URL) -> String {
        // Strip query churn so the same Google photo id reuses one file.
        let base = url.absoluteString.split(separator: "?").first.map(String.init) ?? url.absoluteString
        return base
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
    }

    private static func cacheDirectory() -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return caches.appendingPathComponent(folderName, isDirectory: true)
    }

    private static func fileURL(for key: String) -> URL {
        cacheDirectory().appendingPathComponent(key).appendingPathExtension("jpg")
    }
}

/// Shows a cached profile photo immediately, then refreshes from the network in the background.
struct CachedProfileAvatar<Placeholder: View>: View {
    var url: URL
    var size: CGFloat = 52
    @ViewBuilder var placeholder: () -> Placeholder

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder()
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .task(id: url.absoluteString) {
            await load()
        }
    }

    private func load() async {
        if let cached = ProfileAvatarCache.image(for: url) {
            image = cached
        }

        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .returnCacheDataElseLoad
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                return
            }
            guard let downloaded = UIImage(data: data) else { return }
            ProfileAvatarCache.store(downloaded, for: url)
            image = downloaded
        } catch {
            // Keep whatever we already showed (cache or placeholder).
        }
    }
}
