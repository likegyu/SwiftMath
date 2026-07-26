#if os(macOS)
import XCTest
import AppKit
import CoreText
@testable import SwiftMath

/// 캐스케이드가 어느 경로에서 유실되는지 진단한다.
///
/// 증상: `\text{운동}` 은 명조로 나오는데 `E_{운동}` 의 첨자는 고딕으로 남는다.
/// 가설: 첨자는 script 크기의 폰트가 필요해 `MTFont.copy(withSize:)` 를 거치는데,
/// 그 구현이 `defaultCGFont` 로부터 CTFont 를 **새로 만들어** cascade list 를 잃는다.
final class CJKCascadeDiagnosisTests: XCTestCase {

    private func cascaded(_ name: String, size: CGFloat) -> MTFont? {
        guard let base = MTFontManager.fontManager.latinModernFont(withSize: size) else { return nil }
        let cjk = CTFontDescriptorCreateWithNameAndSize(name as CFString, size)
        let d = CTFontDescriptorCreateCopyWithAttributes(
            CTFontCopyFontDescriptor(base.ctFont),
            [kCTFontCascadeListAttribute: [cjk]] as CFDictionary)
        let copy = base.copy(withSize: size)
        copy.ctFont = CTFontCreateWithFontDescriptor(d, size, nil)
        return copy
    }

    /// 캐스케이드가 걸린 폰트를 copy(withSize:) 하면 살아남는가 — 이것이 핵심 질문.
    func testCascadeSurvivesCopyWithSize() throws {
        let font = try XCTUnwrap(cascaded("NanumMyeongjo", size: 24))

        func cascadeCount(_ f: CTFont) -> Int {
            let d = CTFontCopyFontDescriptor(f)
            let list = CTFontDescriptorCopyAttribute(d, kCTFontCascadeListAttribute) as? [Any]
            return list?.count ?? 0
        }

        let before = cascadeCount(font.ctFont)
        let smaller = font.copy(withSize: 14)          // 첨자 크기로 축소되는 경로
        let after = cascadeCount(smaller.ctFont)

        print("CASCADE before=\(before) afterCopy=\(after)")
        XCTAssertGreaterThan(before, 0, "실험 설정 오류 — 캐스케이드가 애초에 안 걸렸다")
        XCTAssertGreaterThan(after, 0, """
            copy(withSize:) 가 cascade list 를 버린다 — 첨자·분수처럼 크기가 바뀌는 모든 곳에서
            CJK 폴백 폰트 지정이 무효가 된다(before=\(before), after=\(after)).
            """)
    }

    /// 눈으로도 확인할 수 있게 확대 렌더.
    func testRenderZoomedDiagnosis() throws {
        let size: CGFloat = 40
        let font = try XCTUnwrap(cascaded("NanumMyeongjo", size: size))
        let samples = [
            (#"\text{운동}"#, "text — 기준 크기"),
            (#"속도"#, "math — 기준 크기"),
            (#"E_{운동}"#, "math — 첨자(축소 폰트)"),
            (#"\frac{운동}{에너지}"#, "math — 분수(축소 폰트)"),
        ]
        var images: [(NSImage, String)] = []
        for (latex, label) in samples {
            var err: NSError? = nil
            guard let list = MTMathListBuilder.build(fromString: latex, error: &err),
                  let display = MTTypesetter.createLineForMathList(list, font: font, style: .display)
            else { XCTFail("render 실패: \(latex)"); return }
            let pad: CGFloat = 8
            let img = NSImage(size: NSSize(width: display.width + pad * 2,
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
            images.append((img, label))
        }

        let margin: CGFloat = 14, gap: CGFloat = 12
        let width = (images.map { $0.0.size.width }.max() ?? 300) + margin * 2
        let height = images.reduce(margin * 2) { $0 + $1.0.size.height + 18 + gap }
        let sheet = NSImage(size: NSSize(width: width, height: height))
        sheet.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: sheet.size).fill()
        var y = height - margin
        for (img, label) in images {
            y -= img.size.height + 18
            (label as NSString).draw(at: NSPoint(x: margin, y: y + img.size.height),
                                     withAttributes: [.font: NSFont.systemFont(ofSize: 11),
                                                      .foregroundColor: NSColor.systemBlue])
            img.draw(at: NSPoint(x: margin, y: y), from: .zero, operation: .sourceOver, fraction: 1)
            y -= gap
        }
        sheet.unlockFocus()
        let url = URL(fileURLWithPath: "/tmp/swiftmath-cascade-diagnosis.png")
        guard let tiff = sheet.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            XCTFail("PNG 인코딩 실패"); return
        }
        try png.write(to: url)
        print("CASCADE DIAGNOSIS → \(url.path)")
    }
}
#endif
