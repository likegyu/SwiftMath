#if os(macOS)
import XCTest
import AppKit
@testable import SwiftMath
import SwiftMathCJKFonts

/// OpenStax 유기화학 교재(467쪽) 본문에서 **실제로 뽑아낸 표기**로 검증한다.
///
/// 지어낸 예제가 아니라 PDF 텍스트 층에서 정규식으로 긁어낸 것들이다. 이 방식이
/// 손으로 만든 예제가 놓친 결함 둘을 잡았다:
///   · `\ce{H+}` — 붙은 `+` 는 전하인데 구분자로 나왔다(H+ → H⁺)
///   · `\ce{CH2=CH2}` — 결합선 `=` 가 관계연산자 간격을 받아 벌어졌다
///
/// 참고로 그 교재의 **구조식은 전부 삽입 이미지**였다(표본 5쪽에서 벡터 획 0~7개,
/// 이미지 1~4개). 텍스트로 들어오는 건 이런 선형 축약식뿐이라, 2차원 구조식 문법
/// (chemfig)이 파이프라인에 도달할 일은 사실상 없다.
final class RealTextbookChemistryTests: XCTestCase {
    static let real: [(String, String)] = [
        // 교재 텍스트 층에 그대로 있던 축약식
        (#"\ce{CH3CH2CH3}"#, "프로판 — 91쪽"),
        (#"\ce{CH3CH2CH2CH3}"#, "부탄 — 91쪽"),
        (#"\ce{CH3CH2CH2CH2CH3}"#, "펜탄 — 91쪽"),
        (#"\ce{C4H10} \quad \ce{C5H12} \quad \ce{C30H62}"#, "분자식 — 91쪽"),
        (#"\ce{FCH2CH2CH2Br}"#, "할로겐화물 — 77쪽"),
        (#"\ce{HOCH2CH2NH2}"#, "아미노알코올 — 77쪽"),
        (#"\ce{CH3CH2OH} \quad \ce{CH3CO2H}"#, "에탄올·아세트산 — 63쪽"),
        (#"\ce{H3PO4 <=> H2PO4^- + H+}"#, "인산 해리 — 63쪽"),
        (#"\ce{CH3MgBr}"#, "그리냐르 시약 — 70쪽"),
        // 가지 달린 축약식 — 교재는 2줄로 그리지만 모델은 괄호로 편다
        (#"\ce{CH3CH(CH3)CH3}"#, "아이소부탄 (가지)"),
        (#"\ce{(CH3)2CHCH3}"#, "아이소부탄 (괄호 축약)"),
        (#"\ce{(CH3)3CCH3}"#, "2,2-다이메틸프로판"),
        // 반응식
        (#"\ce{CH4 + 2O2 -> CO2 + 2H2O}"#, "연소"),
        (#"\ce{CH2=CH2 + H2 ->[Pd] CH3CH3}"#, "수소 첨가"),
        (#"\ce{CH3CH2Br + OH^- -> CH3CH2OH + Br^-}"#, "친핵성 치환"),
    ]

    func testAllRealFormulasTypeset() throws {
        let font = try XCTUnwrap(MTFontManager.fontManager.latinModernFont(withSize: 22))
            .copy(withCJKSerif: .korean)
        var failures = [String]()
        var rows: [(NSImage, String)] = []
        for (latex, label) in Self.real {
            var e: NSError?
            guard let l = MTMathListBuilder.build(fromString: latex, error: &e), e == nil,
                  let d = MTTypesetter.createLineForMathList(l, font: font, style: .display), d.width > 0
            else { failures.append("\(label): \(latex) — \(e?.localizedDescription ?? "폭 0")"); continue }
            let pad: CGFloat = 8
            let img = NSImage(size: NSSize(width: d.width + pad*2, height: d.ascent + d.descent + pad*2))
            img.lockFocus(); NSColor.white.setFill(); NSRect(origin: .zero, size: img.size).fill()
            if let ctx = NSGraphicsContext.current?.cgContext {
                ctx.saveGState(); ctx.translateBy(x: pad, y: pad + d.descent)
                ctx.setFillColor(NSColor.black.cgColor); d.draw(ctx); ctx.restoreGState()
            }
            img.unlockFocus(); rows.append((img, "\(label)   \(latex)"))
        }
        // 시트로 굽는다
        let margin: CGFloat = 16, gap: CGFloat = 9, labelH: CGFloat = 14
        let width = (rows.map { $0.0.size.width }.max() ?? 400) + margin*2
        let height = rows.reduce(margin*2) { $0 + $1.0.size.height + labelH + gap }
        let sheet = NSImage(size: NSSize(width: max(width, 620), height: height))
        sheet.lockFocus(); NSColor.white.setFill(); NSRect(origin: .zero, size: sheet.size).fill()
        var y = height - margin
        for (img, label) in rows {
            y -= img.size.height + labelH
            (label as NSString).draw(at: NSPoint(x: margin, y: y + img.size.height),
                withAttributes: [.font: NSFont.systemFont(ofSize: 9), .foregroundColor: NSColor.systemBlue])
            img.draw(at: NSPoint(x: margin, y: y), from: .zero, operation: .sourceOver, fraction: 1)
            y -= gap
        }
        sheet.unlockFocus()
        if let tiff = sheet.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try png.write(to: URL(fileURLWithPath: "/tmp/swiftmath-realchem.png"))
            print("REALCHEM → /tmp/swiftmath-realchem.png (\(rows.count)/\(Self.real.count) 조판)")
        }
        XCTAssertTrue(failures.isEmpty, "\(failures.count)개 실패\n" + failures.joined(separator: "\n"))
    }
}
#endif
