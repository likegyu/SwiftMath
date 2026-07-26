//
//  MathImage.swift
//  
//
//  Created by Peter Tang on 15/9/2023.
//

import Foundation

#if os(iOS) || os(visionOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

public struct MathImage {
    public var font: MathFont = .latinModernFont
    public var fontSize: CGFloat
    public var textColor: MTColor

    public var labelMode: MTMathUILabelMode
    public var textAlignment: MTTextAlignment

    public var contentInsets: MTEdgeInsets = MTEdgeInsetsZero

    /// 수학 폰트에 없는 문자(주로 CJK)를 대신 그릴 폰트. 우선순위 순.
    ///
    /// 비워 두면 CoreText 의 시스템 기본 폴백이 고른다 — Apple 플랫폼에서 한글은
    /// AppleSDGothicNeo(고딕)뿐이라, 세리프인 수학 폰트와 한 수식 안에서 서체가 갈린다.
    /// `SwiftMathCJKFonts` 의 `MTCJKSerif` 로 명조를 지정하면 그 불일치가 사라진다.
    public var fallbackFonts: [CTFont] = []

    public let latex: String
    
    private(set) var intrinsicContentSize = CGSize.zero

    public init(latex: String, fontSize: CGFloat, textColor: MTColor, labelMode: MTMathUILabelMode = .display, textAlignment: MTTextAlignment = .center) {
        self.latex = latex
        self.fontSize = fontSize
        self.textColor = textColor
        self.labelMode = labelMode
        self.textAlignment = textAlignment
    }
}
extension MathImage {
    public var currentStyle: MTLineStyle {
        switch labelMode {
            case .display: return .display
            case .text: return .text
        }
    }
    private func intrinsicContentSize(_ displayList: MTMathListDisplay) -> CGSize {
        CGSize(width: displayList.width + contentInsets.left + contentInsets.right,
               height: displayList.ascent + displayList.descent + contentInsets.top + contentInsets.bottom)
    }
    public struct LayoutInfo {
        public var ascent: CGFloat = 0
        public var descent: CGFloat = 0

        public init(ascent: CGFloat, descent: CGFloat) {
            self.ascent = ascent
            self.descent = descent
        }
    }
    public mutating func asImage() -> (NSError?, MTImage?, LayoutInfo?) {
        func layoutImage(size: CGSize, displayList: MTMathListDisplay) {
            var textX = CGFloat(0)
            switch self.textAlignment {
                case .left:   textX = contentInsets.left
                case .center: textX = (size.width - contentInsets.left - contentInsets.right - displayList.width) / 2 + contentInsets.left
                case .right:  textX = size.width - displayList.width - contentInsets.right
            }
            let availableHeight = size.height - contentInsets.bottom - contentInsets.top
            
            // center things vertically
            var height = displayList.ascent + displayList.descent
            if height < fontSize/2 {
                height = fontSize/2  // set height to half the font size
            }
            let textY = (availableHeight - height) / 2 + displayList.descent + contentInsets.bottom
            displayList.position = CGPoint(x: textX, y: textY)
        }
        var error: NSError?
        let mtfont: MTFont? = MTFontV2(font: font, size: fontSize, fallbacks: fallbackFonts)

        guard let mathList = MTMathListBuilder.build(fromString: latex, error: &error), error == nil,
              let displayList = MTTypesetter.createLineForMathList(mathList, font: mtfont, style: currentStyle) else {
            return (error, nil, nil)
        }

        intrinsicContentSize = intrinsicContentSize(displayList)
        displayList.textColor = textColor

        let size = intrinsicContentSize.regularized
        layoutImage(size: size, displayList: displayList)
        
        #if os(iOS) || os(visionOS)
            let renderer = UIGraphicsImageRenderer(size: size)
            let image = renderer.image { rendererContext in
                rendererContext.cgContext.saveGState()
                rendererContext.cgContext.concatenate(.flippedVertically(size.height))
                displayList.draw(rendererContext.cgContext)
                rendererContext.cgContext.restoreGState()
            }
            return (nil, image, LayoutInfo(ascent: displayList.ascent, descent: displayList.descent))
        #endif
        #if os(macOS)
            let image = NSImage(size: size, flipped: false) { bounds in
                guard let context = NSGraphicsContext.current?.cgContext else { return false }
                context.saveGState()
                displayList.draw(context)
                context.restoreGState()
                return true
            }
            return (nil, image, LayoutInfo(ascent: displayList.ascent, descent: displayList.descent))
        #endif
    }
}
private extension CGAffineTransform {
    static func flippedVertically(_ height: CGFloat) -> CGAffineTransform {
        var transform = CGAffineTransform(scaleX: 1, y: -1)
        transform = transform.translatedBy(x: 0, y: -height)
        return transform
    }
}
extension CGSize {
    fileprivate var regularized: CGSize {
        CGSize(width: ceil(width), height: ceil(height))
    }
}
