#if os(macOS)
import XCTest
import AppKit
@testable import SwiftMath
import SwiftMathCJKFonts

/// 쌓기 매크로가 **보기에도** 맞는지 굽는다. 폭·높이 단정만으로는 위·아래가 뒤집혔거나
/// 가운데 정렬이 어긋난 걸 못 잡는다.
///
/// 실행: swift test --filter UnderOverRenderTests   → /tmp/swiftmath-underover.png
final class UnderOverRenderTests: XCTestCase {

    private static let samples: [(String, String)] = [
        (#"\overset{\text{def}}{=}"#, "overset — 정의 기호"),
        (#"\underset{n\to\infty}{\lim} a_n"#, "underset — 극한"),
        (#"A \stackrel{f}{\longrightarrow} B"#, "stackrel — 사상"),
        (#"\sum_{\substack{i<n \\ j<m}} a_{ij}"#, "substack — 여러 줄 조건"),
        (#"\overset{a}{\underset{b}{X}}"#, "위·아래 동시"),
        (#"\overset{정의}{=} \quad \underset{질량}{m}"#, "CJK 장식"),
        (#"\sum_{\substack{속도>0 \\ 가속도<0}} F"#, "CJK substack"),
        (#"x \overset{?}{=} \frac{\overset{a}{b}}{c}"#, "분수 안 중첩"),
        (#"\boxed{E = mc^2}"#, "boxed — 테두리"),
        (#"\boxed{\text{정답}: x = 5}"#, "boxed — CJK"),
        (#"\frac{\cancel{x}\,y}{\cancel{x}} = y"#, "cancel — 약분"),
        (#"\bcancel{a} \quad \xcancel{b} \quad \cancel{속도}"#, "bcancel·xcancel·CJK"),
        (#"\overbrace{a+b}"#, "overbrace — 짧은 내용"),
        (#"\overbrace{a+b+c+d+e+f}^{n\text{개}}"#, "overbrace + 라벨 — 긴 내용"),
        (#"\underbrace{x_1 + x_2 + x_3}_{\text{합}}"#, "underbrace + 라벨"),
        (#"\overbrace{속도 + 가속도}^{\text{운동학}}"#, "overbrace — CJK"),
        (#"\idotsint f\,dV"#, "idotsint"),
        (#"a\phantom{XXX}b \quad a\hphantom{XXX}b"#, "phantom / hphantom"),
        (#"\text{A} \xrightarrow{\text{촉매}} \text{B}"#, "xrightarrow — 화학"),
        (#"\text{A} \xrightarrow[\Delta]{\text{효소, pH 7}} \text{B}"#, "xrightarrow — 위·아래 라벨"),
        (#"x \xleftarrow{f} y \quad a \xleftrightarrow{g} b"#, "xleftarrow / xleftrightarrow"),
        ("\\begin{array}{lcr} 항목 & 기호 & 값 \\\\ 속도 & v & 3 \\\\ 질량 & m & 5 \\end{array}", "array — 열 정렬 l·c·r"),
        ("\\left[\\begin{array}{cc} a & b \\\\ c & d \\end{array}\\right]", "array + 구분자"),
        (#"\underrightarrow{AB} \quad \overparen{CD}"#, "under/over 늘어나는 악센트"),
    ]

    func testRenderUnderOverSheet() throws {
        let size: CGFloat = 24
        let font = try XCTUnwrap(MTFontManager.fontManager.latinModernFont(withSize: size))
            .copy(withCJKSerif: .korean, .simplifiedChinese)

        var rows: [(NSImage, String)] = []
        for (latex, label) in Self.samples {
            var err: NSError?
            guard let list = MTMathListBuilder.build(fromString: latex, error: &err), err == nil,
                  let display = MTTypesetter.createLineForMathList(list, font: font, style: .display)
            else { XCTFail("조판 실패: \(latex) — \(err?.localizedDescription ?? "")"); continue }
            let pad: CGFloat = 8
            let img = NSImage(size: NSSize(width: max(display.width + pad * 2, 20),
                                           height: display.ascent + display.descent + pad * 2))
            img.lockFocus()
            NSColor.white.setFill()
            NSRect(origin: .zero, size: img.size).fill()
            if let ctx = NSGraphicsContext.current?.cgContext {
                ctx.saveGState()
                ctx.translateBy(x: pad, y: pad + display.descent)
                ctx.setFillColor(NSColor.black.cgColor)
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

        let url = URL(fileURLWithPath: "/tmp/swiftmath-underover.png")
        guard let tiff = sheet.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            XCTFail("PNG 인코딩 실패"); return
        }
        try png.write(to: url)
        print("UNDEROVER RENDER → \(url.path)")
    }
}
#endif
