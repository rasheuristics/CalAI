import SwiftUI

class FontManager: ObservableObject {
    @Published var currentFontSize: FontSize = .medium

    func scaledFont(_ font: Font) -> Font {
        switch font {
        case .largeTitle:
            return .largeTitle
        case .title:
            return .title
        case .title2:
            return .title2
        case .title3:
            return .title3
        case .headline:
            return .headline
        case .subheadline:
            return .subheadline
        case .body:
            return .body
        case .callout:
            return .callout
        case .footnote:
            return .footnote
        case .caption:
            return .caption
        case .caption2:
            return .caption2
        default:
            return font
        }
    }

    func scaledSystemFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return .system(size: size * currentFontSize.scaleFactor, weight: weight)
    }
}

extension View {
    func scaledFont(_ font: Font, fontManager: FontManager) -> some View {
        self.font(fontManager.scaledFont(font))
    }

    func dynamicFont(size: CGFloat, weight: Font.Weight = .regular, fontManager: FontManager) -> some View {
        self.font(fontManager.scaledSystemFont(size: size, weight: weight))
    }

    // Support iOS Dynamic Type with custom sizes
    func accessibleFont(size: CGFloat, weight: Font.Weight = .regular, relativeTo textStyle: Font.TextStyle = .body) -> some View {
        self.font(.system(size: size, weight: weight, design: .default))
            .dynamicTypeSize(.large ... .accessibility3)
    }
}