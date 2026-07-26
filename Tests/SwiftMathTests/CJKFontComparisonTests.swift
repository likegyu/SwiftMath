#if os(macOS)
import XCTest
import AppKit
import CoreText
@testable import SwiftMath

/// CJK 폴백 폰트 비교 실험 — 수식 안 한글을 어떤 폰트로 그릴지 **보고 판단**하기 위한 도구.
///
/// 기본 상태에서는 CoreText 시스템 폴백이 골라 주는 폰트(macOS·iOS 모두 AppleSDGothicNeo,
/// 고딕)가 쓰인다. 수학 폰트(Latin Modern)는 세리프라 한 수식 안에서 라틴은 세리프,
/// 한글은 산세리프가 되는 내부 불일치가 생긴다. 명조 계열을 캐스케이드로 얹으면 어떻게
/// 달라지는지 같은 수식을 두 벌 렌더해 나란히 굽는다.
///
/// 실행: swift test --filter CJKFontComparisonTests   → /tmp/swiftmath-cjk-fonts.png
final class CJKFontComparisonTests: XCTestCase {

    private static let samples = [
        #"E_{운동} = \frac{1}{2}mv^2"#,
        #"속도 = 5"#,
        #"\text{운동 에너지}"#,
    ]

    /// 주어진 폰트 이름을 폴백 체인 맨 앞에 얹은 MTFont 사본.
    private func fontWithCJKCascade(_ cjkFontName: String?, size: CGFloat) -> MTFont? {
        guard let base = MTFontManager.fontManager.latinModernFont(withSize: size) else { return nil }
        guard let cjkFontName else { return base }
        let cjk = CTFontDescriptorCreateWithNameAndSize(cjkFontName as CFString, size)
        let descriptor = CTFontCopyFontDescriptor(base.ctFont)
        let cascaded = CTFontDescriptorCreateCopyWithAttributes(
            descriptor, [kCTFontCascadeListAttribute: [cjk]] as CFDictionary)
        // MTFont 는 참조 타입이라 사본을 만들어 교체한다(원본 캐시 오염 방지).
        let copy = base.copy(withSize: size)
        copy.ctFont = CTFontCreateWithFontDescriptor(cascaded, size, nil)
        return copy
    }

    private func render(_ latex: String, font: MTFont?, size: CGFloat) -> NSImage? {
        var err: NSError? = nil
        guard let list = MTMathListBuilder.build(fromString: latex, error: &err),
              let font,
              let display = MTTypesetter.createLineForMathList(list, font: font, style: .display)
        else { return nil }
        let pad: CGFloat = 6
        let image = NSImage(size: NSSize(width: display.width + pad * 2,
                                         height: display.ascent + display.descent + pad * 2))
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: image.size).fill()
        if let ctx = NSGraphicsContext.current?.cgContext {
            ctx.saveGState()
            ctx.translateBy(x: pad, y: pad + display.descent)
            ctx.setFillColor(NSColor.black.cgColor)
            display.draw(ctx)
            ctx.restoreGState()
        }
        image.unlockFocus()
        return image
    }

    func testRenderCJKFontComparison() throws {
        let size: CGFloat = 24
        // iOS 실측(KoreanFontAvailabilityTests): 한글 폰트는 AppleSDGothicNeo 7개 굵기가
        // 전부이고 명조 계열은 없다. 따라서 Light/Thin 은 번들 0MB로 쓸 수 있는 후보이고,
        // NanumMyeongjo 는 폰트를 패키지에 넣어야만 가능한 선택지(비교 기준으로만 렌더).
        let variants: [(String, String?)] = [
            ("현행 — 시스템 폴백(AppleSDGothicNeo Regular)", nil),
            ("Light — 번들 0MB", "AppleSDGothicNeo-Light"),
            ("Thin — 번들 0MB", "AppleSDGothicNeo-Thin"),
            ("나눔명조 — 번들 필요(~13MB)", "NanumMyeongjo"),
        ]

        var columns: [[NSImage]] = []
        for (_, fontName) in variants {
            let font = fontWithCJKCascade(fontName, size: size)
            var images: [NSImage] = []
            for latex in Self.samples {
                guard let img = render(latex, font: font, size: size) else {
                    XCTFail("render 실패: \(latex)"); return
                }
                images.append(img)
            }
            columns.append(images)
        }

        // 같은 수식을 위아래로 붙여 직접 비교하게 한다.
        let labelFont = NSFont.systemFont(ofSize: 11)
        let rowGap: CGFloat = 10, groupGap: CGFloat = 22, margin: CGFloat = 14
        var totalHeight = margin * 2
        var maxWidth: CGFloat = 320
        for i in Self.samples.indices {
            for c in columns.indices {
                totalHeight += columns[c][i].size.height + 16 + rowGap
                maxWidth = max(maxWidth, columns[c][i].size.width)
            }
            totalHeight += groupGap
        }
        let sheet = NSImage(size: NSSize(width: maxWidth + margin * 2, height: totalHeight))
        sheet.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: sheet.size).fill()
        var y = totalHeight - margin
        for i in Self.samples.indices {
            for c in columns.indices {
                let img = columns[c][i]
                y -= (img.size.height + 16)
                (variants[c].0 as NSString).draw(
                    at: NSPoint(x: margin, y: y + img.size.height),
                    withAttributes: [.font: labelFont,
                                     .foregroundColor: c == 0 ? NSColor.gray : NSColor.systemBlue])
                img.draw(at: NSPoint(x: margin, y: y), from: .zero, operation: .sourceOver, fraction: 1)
                y -= rowGap
            }
            y -= groupGap
        }
        sheet.unlockFocus()

        let url = URL(fileURLWithPath: "/tmp/swiftmath-cjk-fonts.png")
        guard let tiff = sheet.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            XCTFail("PNG 인코딩 실패"); return
        }
        try png.write(to: url)
        print("CJK FONT COMPARISON → \(url.path)")
    }
}
#endif
