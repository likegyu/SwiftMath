#if os(macOS)
import XCTest
import AppKit
@testable import SwiftMath
import SwiftMathCJKFonts

/// 색이 실제 화면에 나오는지 굽는다. 단정만으로는 "색을 걸었다"와 "색이 보인다"를 못 가른다.
///
/// 실행: swift test --filter ColorRenderTests   → /tmp/swiftmath-color.png
final class ColorRenderTests: XCTestCase {

    private static let samples: [(String, String)] = [
        (#"a + \textcolor{red}{b} + c"#, "textcolor — 일부만"),
        (#"\textcolor{blue}{\frac{a}{b}}"#, "구조 전체에 색"),
        (#"\colorbox{yellow}{정답} = 5"#, "colorbox — 배경"),
        (#"\textcolor{red}{\text{중요}}: v = \frac{s}{t}"#, "CJK에 색"),
        (#"\textcolor{#008000}{x^2} + \textcolor{purple}{y^2}"#, "16진수 + 이름"),
        (#"\textcolor{chartreuse}{모르는색}"#, "모르는 이름 — 내용은 남아야"),
        (#"\boxed{\textcolor{red}{정답}}"#, "테두리 + 색"),
    ]

    func testRenderColorSheet() throws {
        let size: CGFloat = 24
        let font = try XCTUnwrap(MTFontManager.fontManager.latinModernFont(withSize: size))
            .copy(withCJKSerif: .korean)

        var rows: [(NSImage, String)] = []
        for (latex, label) in Self.samples {
            var err: NSError?
            guard let list = MTMathListBuilder.build(fromString: latex, error: &err), err == nil,
                  let display = MTTypesetter.createLineForMathList(list, font: font, style: .display)
            else { XCTFail("조판 실패: \(latex) — \(err?.localizedDescription ?? "")"); continue }
            // 앱과 같은 순서: 전체 색을 나중에 덮어쓴다. 개별 색이 살아남아야 한다.
            display.textColor = MTColor.black

            let pad: CGFloat = 8
            let img = NSImage(size: NSSize(width: max(display.width + pad * 2, 20),
                                           height: display.ascent + display.descent + pad * 2))
            img.lockFocus()
            NSColor.white.setFill()
            NSRect(origin: .zero, size: img.size).fill()
            if let ctx = NSGraphicsContext.current?.cgContext {
                ctx.saveGState()
                ctx.translateBy(x: pad, y: pad + display.descent)
                display.draw(ctx)
                ctx.restoreGState()
            }
            img.unlockFocus()
            rows.append((img, "\(label)   \(latex)"))
        }

        let margin: CGFloat = 16, gap: CGFloat = 10, labelH: CGFloat = 15
        let width = (rows.map { $0.0.size.width }.max() ?? 400) + margin * 2
        let height = rows.reduce(margin * 2) { $0 + $1.0.size.height + labelH + gap }
        let sheet = NSImage(size: NSSize(width: max(width, 520), height: height))
        sheet.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: sheet.size).fill()
        var y = height - margin
        for (img, label) in rows {
            y -= img.size.height + labelH
            (label as NSString).draw(at: NSPoint(x: margin, y: y + img.size.height),
                                     withAttributes: [.font: NSFont.systemFont(ofSize: 10),
                                                      .foregroundColor: NSColor.systemBlue])
            img.draw(at: NSPoint(x: margin, y: y), from: .zero, operation: .sourceOver, fraction: 1)
            y -= gap
        }
        sheet.unlockFocus()

        let url = URL(fileURLWithPath: "/tmp/swiftmath-color.png")
        guard let tiff = sheet.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            XCTFail("PNG 인코딩 실패"); return
        }
        try png.write(to: url)
        print("COLOR RENDER → \(url.path)")
    }
}
#endif
