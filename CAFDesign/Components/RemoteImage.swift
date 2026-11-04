import SwiftUI
import UIKit

/// Two-level image cache: memory (NSCache) over URLCache disk. Decoded + downsampled once.
final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()
    private let session: URLSession
    init() {
        cache.countLimit = 200
        cache.totalCostLimit = 64 << 20
        let c = URLSessionConfiguration.default
        c.urlCache = URLCache(memoryCapacity: 16 << 20, diskCapacity: 150 << 20)
        c.requestCachePolicy = .returnCacheDataElseLoad
        c.httpCookieStorage = nil
        session = URLSession(configuration: c)
    }

    private func key(_ url: URL, _ maxPixel: CGFloat) -> NSString { "\(url.absoluteString)#\(Int(maxPixel))" as NSString }
    func cached(_ url: URL, maxPixel: CGFloat = 900) -> UIImage? { cache.object(forKey: key(url, maxPixel)) }

    func load(_ url: URL, maxPixel: CGFloat = 900) async -> UIImage? {
        if let img = cached(url, maxPixel: maxPixel) { return img }
        guard let (data, resp) = try? await session.data(from: url),
              (resp as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? true,
              let img = Self.downsample(data, maxPixel: maxPixel) else { return nil }
        cache.setObject(img, forKey: key(url, maxPixel), cost: Int(img.size.width * img.size.height * 4))
        return img
    }

    func removeAll() { cache.removeAllObjects(); session.configuration.urlCache?.removeAllCachedResponses() }

    private static func downsample(_ data: Data, maxPixel: CGFloat) -> UIImage? {
        let opts: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let src = CGImageSourceCreateWithData(data as CFData, opts as CFDictionary) else { return nil }
        let thumb: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceShouldCacheImmediately: true,
                                      kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: maxPixel]
        return CGImageSourceCreateThumbnailAtIndex(src, 0, thumb as CFDictionary).map(UIImage.init(cgImage:))
    }
}

struct RemoteImage<Placeholder: View>: View {
    let url: URL?
    var contentMode: ContentMode = .fill
    /// Decode budget in pixels (longest side). Thumbnails, logos and avatars pass a small value; the cache keeps one size per URL.
    var maxPixel: CGFloat = 900
    @ViewBuilder var placeholder: () -> Placeholder
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image).resizable().aspectRatio(contentMode: contentMode).transition(.opacity)
            } else if failed || url == nil {
                placeholder()
            } else {
                Color.surfaceSunken
            }
        }
        .task(id: url) {
            guard let url else { return }
            if let c = ImageCache.shared.cached(url, maxPixel: maxPixel) { image = c; return }
            image = nil; failed = false
            if let img = await ImageCache.shared.load(url, maxPixel: maxPixel) { withAnimation(.easeOut(duration: 0.2)) { image = img } } else { failed = true }
        }
    }
}

extension RemoteImage where Placeholder == AnyView {
    init(url: URL?, contentMode: ContentMode = .fill, maxPixel: CGFloat = 900) {
        self.init(url: url, contentMode: contentMode, maxPixel: maxPixel) {
            AnyView(ZStack { Color.surfaceSunken; IconView(icon: .package, size: 28).foregroundStyle(Color.textMuted) })
        }
    }
}

/// Circular avatar: image or initials on a surface disc.
struct AvatarView: View {
    let url: URL?
    let name: String
    var size: CGFloat = 72
    var body: some View {
        Group {
            if url != nil {
                RemoteImage(url: url, maxPixel: max(160, size * 3)) { initials }
            } else { initials }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color.hairline, lineWidth: 1))
        .accessibilityLabel(Text(name)).accessibilityAddTraits(.isImage)
    }
    private var initials: some View {
        ZStack {
            Color.surfaceSunken
            Text(String(name.trimmed.first.map(String.init) ?? "•")).font(.brandHeading).foregroundStyle(Color.accentText)
        }
    }
}
