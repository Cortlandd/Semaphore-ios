import Foundation
import ImageIO
import SwiftUI
import UIKit

enum SemaphorePalette {
    static let background = Color(red: 0.9725, green: 0.9725, blue: 0.9804)
    static let headerBackground = Color(red: 0.9490, green: 0.9490, blue: 0.9686)
    static let grid = Color.gray.opacity(0.15)
    static let primary = Color(red: 0.4157, green: 0.3529, blue: 0.8039)
    static let accent = Color(red: 0.1765, green: 0.1922, blue: 0.2588)
    static let card = Color.white
    static let secondaryText = Color.gray
    static let success = Color(red: 0.2706, green: 0.6471, blue: 0.3412)
    static let danger = Color(red: 0.8784, green: 0.3294, blue: 0.2431)
}

struct GridBackground<Content: View>: View {
    var backgroundColor: Color = SemaphorePalette.background
    var content: Content

    init(
        backgroundColor: Color = SemaphorePalette.background,
        @ViewBuilder content: () -> Content
    ) {
        self.backgroundColor = backgroundColor
        self.content = content()
    }

    var body: some View {
        ZStack {
            backgroundColor
                .overlay(GridPattern().stroke(SemaphorePalette.grid, lineWidth: 0.8))
                .ignoresSafeArea()

            LinearGradient(
                colors: [.clear, .clear, backgroundColor],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            content
        }
    }
}

struct GridPattern: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step: CGFloat = 40

        stride(from: step, through: rect.width, by: step).forEach { x in
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
        }

        stride(from: step, through: rect.height, by: step).forEach { y in
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
        }

        return path
    }
}

struct CapsuleIconButton: View {
    var systemImage: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.black)
                .frame(width: 48, height: 48)
                .background(Color.white, in: Circle())
                .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}

struct StatCard<Content: View>: View {
    var background: Color
    var content: Content

    init(background: Color, @ViewBuilder content: () -> Content) {
        self.background = background
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
            .padding(20)
            .background(background, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
    }
}

struct WorkoutMediaView: View {
    var imageLocation: String?
    var selectedData: Data?
    var height: CGFloat
    var cornerRadius: CGFloat
    var overlayIcon: String?

    @State private var loadedData: Data?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.9))

            if let data = selectedData ?? loadedData {
                AnimatedImage(data: data)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            } else {
                VStack(spacing: 10) {
                    Image(systemName: overlayIcon ?? "figure.cooldown")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(SemaphorePalette.primary)

                    Text("Add Cover Media")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(SemaphorePalette.accent)
                }
            }
        }
        .frame(height: height)
        .task(id: imageLocation) {
            guard selectedData == nil else { return }
            loadedData = await loadMediaData(from: imageLocation)
        }
    }
}

struct AnimatedImage: UIViewRepresentable {
    var data: Data

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }

    func updateUIView(_ imageView: UIImageView, context: Context) {
        imageView.image = UIImage.animatedImage(withAnimatedData: data) ?? UIImage(data: data)
    }
}

func loadMediaData(from imageLocation: String?) async -> Data? {
    guard let imageLocation, !imageLocation.isEmpty else { return nil }

    if let url = URL(string: imageLocation), url.isFileURL {
        return try? Data(contentsOf: url)
    }

    if let url = URL(string: imageLocation) {
        return try? await URLSession.shared.data(from: url).0
    }

    return nil
}

private extension UIImage {
    static func animatedImage(withAnimatedData data: Data) -> UIImage? {
        guard data.starts(with: [0x47, 0x49, 0x46]),
              let source = CGImageSourceCreateWithData(data as CFData, nil)
        else {
            return nil
        }

        let frameCount = CGImageSourceGetCount(source)
        var images: [UIImage] = []
        var duration: Double = 0

        for index in 0..<frameCount {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else {
                continue
            }

            let frameDuration = gifFrameDuration(at: index, source: source)
            duration += frameDuration
            images.append(UIImage(cgImage: cgImage))
        }

        guard !images.isEmpty else { return nil }
        return UIImage.animatedImage(with: images, duration: max(duration, 0.1))
    }

    static func gifFrameDuration(at index: Int, source: CGImageSource) -> Double {
        let defaultFrameDuration = 0.1
        guard
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
            let gifProperties = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        else {
            return defaultFrameDuration
        }

        let unclamped = gifProperties[kCGImagePropertyGIFUnclampedDelayTime] as? Double
        let clamped = gifProperties[kCGImagePropertyGIFDelayTime] as? Double
        let duration = unclamped ?? clamped ?? defaultFrameDuration
        return duration < 0.011 ? defaultFrameDuration : duration
    }
}
