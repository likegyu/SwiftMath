#if os(macOS)
import XCTest
import AppKit
import CoreText
@testable import SwiftMath
import SwiftMathCJKFonts

/// 번들 명조가 실제 조판에 적용된 모습을 눈으로 확인한다.
///
/// 폭·캐스케이드 단정만으로는 "지정한 폰트가 맞게 나왔는지"를 알 수 없다. 첨자·분수·근호
/// 처럼 크기가 바뀌는 경로에서만 서체가 되돌아가는 버그를 이미 한 번 겪었기 때문에,
/// 그 경로들을 한 장에 모아 굽는다.
///
/// 실행: swift test --filter CJKSerifRenderTests   → /tmp/swiftmath-cjk-serif.png
final class CJKSerifRenderTests: XCTestCase {

    private static let samples = [
        (#"E_{운동} = \frac{1}{2}mv^2"#, "첨자 + 분수 (축소 폰트 경로)"),
        (#"\text{운동 에너지}"#, "\\text 그룹"),
        (#"속도 = 5 \text{ m/s}"#, "수식 모드 한글"),
        (#"\sqrt{\frac{질량}{부피}} = 밀도"#, "근호 안 분수"),
        (#"\sum_{i=1}^{n} 원소_i \approx \int_0^\infty f(x)\,dx"#, "큰 연산자 첨자"),
        (#"\vec{속도} + \hat{방향}"#, "악센트 (글리프 경로)"),
        (#"化学: \text{H}_2\text{O} \rightarrow 水"#, "한자 혼합"),
    ]

    private func render(_ latex: String, font: MTFont) -> NSImage? {
        var err: NSError?
        guard let list = MTMathListBuilder.build(fromString: latex, error: &err),
              let display = MTTypesetter.createLineForMathList(list, font: font, style: .display)
        else { return nil }
        let pad: CGFloat = 6
        let image = NSImage(size: NSSize(width: max(display.width + pad * 2, 10),
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

    func testRenderSerifComparison() throws {
        let size: CGFloat = 26
        let base = try XCTUnwrap(MTFontManager.fontManager.latinModernFont(withSize: size))
        let variants: [(String, MTFont)] = [
            ("현행 — 시스템 폴백 (고딕)", base),
            ("번들 명조 — SwiftMath Serif KR + SC", base.copy(withCJKSerif: .korean, .simplifiedChinese)),
        ]

        var rows: [(NSImage, String, Bool)] = []
        for (latex, label) in Self.samples {
            for (variantName, font) in variants {
                let img = try XCTUnwrap(self.render(latex, font: font), "조판 실패: \(latex)")
                rows.append((img, "\(label) — \(variantName)", variantName.hasPrefix("번들")))
            }
        }

        let margin: CGFloat = 16, gap: CGFloat = 8, labelH: CGFloat = 15
        let width = (rows.map { $0.0.size.width }.max() ?? 400) + margin * 2
        let height = rows.reduce(margin * 2) { $0 + $1.0.size.height + labelH + gap }
        let sheet = NSImage(size: NSSize(width: max(width, 460), height: height))
        sheet.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: sheet.size).fill()
        var y = height - margin
        for (img, label, highlighted) in rows {
            y -= img.size.height + labelH
            (label as NSString).draw(
                at: NSPoint(x: margin, y: y + img.size.height),
                withAttributes: [.font: NSFont.systemFont(ofSize: 10),
                                 .foregroundColor: highlighted ? NSColor.systemBlue : NSColor.gray])
            img.draw(at: NSPoint(x: margin, y: y), from: .zero, operation: .sourceOver, fraction: 1)
            y -= gap
        }
        sheet.unlockFocus()

        let url = URL(fileURLWithPath: "/tmp/swiftmath-cjk-serif.png")
        guard let tiff = sheet.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            XCTFail("PNG 인코딩 실패"); return
        }
        try png.write(to: url)
        print("CJK SERIF RENDER → \(url.path)")
    }
}
#endif
