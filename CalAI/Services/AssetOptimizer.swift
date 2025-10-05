import SwiftUI
import UIKit

/// Optimizes image and asset loading for better performance
class AssetOptimizer {
    static let shared = AssetOptimizer()

    private let imageCache = NSCache<NSString, UIImage>()
    private let cacheQueue = DispatchQueue(label: "com.calai.imagecache")

    private init() {
        // Configure image cache
        imageCache.countLimit = 50 // Max 50 images
        imageCache.totalCostLimit = 100 * 1024 * 1024 // 100 MB

        // Listen for memory warnings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Image Loading

    /// Load and cache image with optional downsampling
    func loadImage(
        named: String,
        targetSize: CGSize? = nil,
        completion: @escaping (UIImage?) -> Void
    ) {
        // Check cache first
        if let cached = imageCache.object(forKey: named as NSString) {
            completion(cached)
            return
        }

        // Load asynchronously
        DispatchQueue.global(qos: .userInitiated).async {
            var image = UIImage(named: named)

            // Downsample if needed
            if let targetSize = targetSize, let original = image {
                image = self.downsample(image: original, to: targetSize)
            }

            // Cache it
            if let finalImage = image {
                let cost = self.estimateImageCost(finalImage)
                self.imageCache.setObject(finalImage, forKey: named as NSString, cost: cost)
            }

            DispatchQueue.main.async {
                completion(image)
            }
        }
    }

    /// Load image from URL with caching
    func loadImage(
        from url: URL,
        targetSize: CGSize? = nil,
        completion: @escaping (UIImage?) -> Void
    ) {
        let cacheKey = url.absoluteString as NSString

        // Check cache
        if let cached = imageCache.object(forKey: cacheKey) {
            completion(cached)
            return
        }

        // Download asynchronously
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self,
                  let data = data,
                  var image = UIImage(data: data) else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }

            // Downsample if needed
            if let targetSize = targetSize {
                image = self.downsample(image: image, to: targetSize)
            }

            // Cache it
            let cost = self.estimateImageCost(image)
            self.imageCache.setObject(image, forKey: cacheKey, cost: cost)

            DispatchQueue.main.async {
                completion(image)
            }
        }.resume()
    }

    // MARK: - Image Optimization

    /// Downsample image to target size (memory efficient)
    private func downsample(image: UIImage, to targetSize: CGSize) -> UIImage {
        let imageSize = image.size

        // Check if downsampling is needed
        guard imageSize.width > targetSize.width || imageSize.height > targetSize.height else {
            return image
        }

        // Calculate scale
        let widthRatio = targetSize.width / imageSize.width
        let heightRatio = targetSize.height / imageSize.height
        let scale = min(widthRatio, heightRatio)

        let scaledSize = CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )

        // Render at smaller size
        let renderer = UIGraphicsImageRenderer(size: scaledSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: scaledSize))
        }
    }

    /// Estimate memory cost of an image
    private func estimateImageCost(_ image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 0 }
        return cgImage.bytesPerRow * cgImage.height
    }

    @objc private func handleMemoryWarning() {
        imageCache.removeAllObjects()
        print("⚠️ Memory warning - image cache cleared")
    }

    // MARK: - Prefetching

    /// Prefetch images for better scrolling performance
    func prefetchImages(named names: [String], targetSize: CGSize? = nil) {
        DispatchQueue.global(qos: .background).async {
            for name in names {
                self.loadImage(named: name, targetSize: targetSize) { _ in }
            }
        }
    }

    /// Clear specific image from cache
    func clearImage(named: String) {
        imageCache.removeObject(forKey: named as NSString)
    }

    /// Clear all cached images
    func clearAllImages() {
        imageCache.removeAllObjects()
    }
}

// MARK: - SwiftUI Image Extensions

extension Image {
    /// Load and display image with optimization
    static func optimized(_ name: String, targetSize: CGSize? = nil) -> some View {
        OptimizedImage(name: name, targetSize: targetSize)
    }
}

struct OptimizedImage: View {
    let name: String
    let targetSize: CGSize?

    @State private var uiImage: UIImage?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let uiImage = uiImage {
                Image(uiImage: uiImage)
                    .resizable()
            } else if isLoading {
                ProgressView()
            } else {
                Image(systemName: "photo")
                    .foregroundColor(.gray)
            }
        }
        .onAppear {
            loadImage()
        }
    }

    private func loadImage() {
        AssetOptimizer.shared.loadImage(named: name, targetSize: targetSize) { image in
            self.uiImage = image
            self.isLoading = false
        }
    }
}

// MARK: - Asset Preloading

class AssetPreloader {
    /// Preload commonly used SF Symbols
    static func preloadSFSymbols() {
        let commonSymbols = [
            "calendar",
            "calendar.badge.plus",
            "person.2.fill",
            "location.fill",
            "clock.fill",
            "bell.fill",
            "chevron.left",
            "chevron.right",
            "checkmark.circle.fill",
            "xmark.circle.fill",
            "exclamationmark.triangle.fill"
        ]

        for symbol in commonSymbols {
            _ = UIImage(systemName: symbol)
        }

        print("✅ Preloaded \(commonSymbols.count) SF Symbols")
    }

    /// Preload app icons and graphics
    static func preloadAppAssets() {
        let appAssets = [
            "AppIcon",
            // Add other asset names here
        ]

        AssetOptimizer.shared.prefetchImages(named: appAssets)
        print("✅ Preloading \(appAssets.count) app assets")
    }
}

// MARK: - Lazy Loading View Modifier

struct LazyLoadModifier: ViewModifier {
    let threshold: CGFloat
    let action: () -> Void

    @State private var hasLoaded = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                if !hasLoaded {
                    action()
                    hasLoaded = true
                }
            }
    }
}

extension View {
    /// Lazy load content when view appears
    func lazyLoad(threshold: CGFloat = 0, action: @escaping () -> Void) -> some View {
        self.modifier(LazyLoadModifier(threshold: threshold, action: action))
    }
}
