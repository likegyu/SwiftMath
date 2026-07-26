#if os(macOS)
import XCTest
import AppKit
@testable import SwiftMath
import SwiftMathCJKFonts

/// 화학식·단위가 실제로 어떻게 나오는지 굽는다.
/// 실행: swift test --filter ScienceRenderTests   → /tmp/swiftmath-science.png
final class ScienceRenderTests: XCTestCase {
    private static let samples: [(String, String)] = [
        (#"\ce{H2SO4}"#, "아래첨자"),
        (#"\ce{2H2 + O2 -> 2H2O}"#, "반응식 + 계수"),
        (#"\ce{N2 + 3H2 <=> 2NH3}"#, "평형"),
        (#"\ce{CH4 + 2O2 ->[점화] CO2 + 2H2O}"#, "라벨 달린 화살표"),
        (#"\ce{NaCl(aq) + AgNO3(aq) -> AgCl v + NaNO3(aq)}"#, "상태 + 침전"),
        (#"\ce{Fe^{3+} + 3OH^- -> Fe(OH)3}"#, "전하 + 괄호"),
        (#"\ce{CuSO4*5H2O}"#, "수화물"),
        (#"\ce{^{227}_{90}Th}"#, "동위원소"),
        (#"v = \SI{9.8}{\meter\per\second\squared}"#, "단위 — 분모·거듭제곱"),
        (#"N_A = \SI{6.022e23}{\per\mole}"#, "지수 표기"),
        (#"\SI{25}{\celsius} \quad \SI{100}{\percent} \quad \si{\ohm}"#, "섭씨·퍼센트·옴"),
        (#"\text{끓는점}: \SI{373}{\kelvin} = \SI{100}{\celsius}"#, "CJK 혼합"),
    ]

    func testRenderScienceSheet() throws {
        let size: CGFloat = 24
        let font = try XCTUnwrap(MTFontManager.fontManager.latinModernFont(withSize: size))
            .copy(withCJKSerif: .korean)
        var rows: [(NSImage, String)] = []
        for (latex, label) in Self.samples {
            var err: NSError?
            guard let list = MTMathListBuilder.build(fromString: latex, error: &err), err == nil,
                  let display = MTTypesetter.createLineForMathList(list, font: font, style: .display)
            else { XCTFail("조판 실패: \(latex) — \(err?.localizedDescription ?? "")"); continue }
            let pad: CGFloat = 8
            let img = NSImage(size: NSSize(width: max(display.width + pad*2, 20),
                                           height: display.ascent + display.descent + pad*2))
            img.lockFocus()
            NSColor.white.setFill(); NSRect(origin: .zero, size: img.size).fill()
            if let ctx = NSGraphicsContext.current?.cgContext {
                ctx.saveGState(); ctx.translateBy(x: pad, y: pad + display.descent)
                ctx.setFillColor(NSColor.black.cgColor); display.draw(ctx); ctx.restoreGState()
            }
            img.unlockFocus()
            rows.append((img, "\(label)   \(latex)"))
        }
        let margin: CGFloat = 16, gap: CGFloat = 10, labelH: CGFloat = 15
        let width = (rows.map { $0.0.size.width }.max() ?? 400) + margin*2
        let height = rows.reduce(margin*2) { $0 + $1.0.size.height + labelH + gap }
        let sheet = NSImage(size: NSSize(width: max(width, 560), height: height))
        sheet.lockFocus()
        NSColor.white.setFill(); NSRect(origin: .zero, size: sheet.size).fill()
        var y = height - margin
        for (img, label) in rows {
            y -= img.size.height + labelH
            (label as NSString).draw(at: NSPoint(x: margin, y: y + img.size.height),
                withAttributes: [.font: NSFont.systemFont(ofSize: 10), .foregroundColor: NSColor.systemBlue])
            img.draw(at: NSPoint(x: margin, y: y), from: .zero, operation: .sourceOver, fraction: 1)
            y -= gap
        }
        sheet.unlockFocus()
        let url = URL(fileURLWithPath: "/tmp/swiftmath-science.png")
        guard let tiff = sheet.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { XCTFail("PNG"); return }
        try png.write(to: url)
        print("SCIENCE RENDER → \(url.path)")
    }
}
#endif
