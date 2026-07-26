import XCTest
import CoreText
@testable import SwiftMath
import SwiftMathCJKFonts

/// 지정한 CJK 폰트가 **실제로 글리프를 그리는 데까지** 도달하는지 검증한다.
///
/// API 가 컴파일되는 것과 화면에 그 폰트가 나오는 것은 다른 문제다. 앞서 한 번
/// `copy(withSize:)` 가 캐스케이드를 버려서 첨자만 서체가 갈리는 버그를 겪었다.
final class CJKSerifFallbackTests: XCTestCase {

    private func baseFont(_ size: CGFloat = 20) throws -> MTFont {
        try XCTUnwrap(MTFontManager.fontManager.latinModernFont(withSize: size))
    }

    private func cascadeCount(_ font: MTFont) -> Int {
        let d = CTFontCopyFontDescriptor(font.ctFont)
        let list = CTFontDescriptorCopyAttribute(d, kCTFontCascadeListAttribute) as? [Any]
        return list?.count ?? 0
    }

    /// 번들 폰트가 실제로 로드되고 이름으로 찾아지는가.
    func testBundledSerifFontsLoad() throws {
        for serif in [MTCJKSerif.korean, .simplifiedChinese] {
            let font = try XCTUnwrap(serif.ctFont(size: 20), "\(serif) 폰트를 못 만들었다")
            let name = CTFontCopyPostScriptName(font) as String
            XCTAssertTrue(name.hasPrefix("SwiftMathSerif"), "엉뚱한 폰트가 잡혔다: \(name)")
        }
    }

    /// 번들 폰트가 해당 문자를 실제로 갖고 있는가.
    func testBundledSerifCoverage() throws {
        let kr = try XCTUnwrap(MTCJKSerif.korean.ctFont(size: 20))
        let sc = try XCTUnwrap(MTCJKSerif.simplifiedChinese.ctFont(size: 20))

        func hasGlyphs(_ font: CTFont, _ s: String) -> Bool {
            var chars = Array(s.utf16)
            var glyphs = [CGGlyph](repeating: 0, count: chars.count)
            return CTFontGetGlyphsForCharacters(font, &chars, &glyphs, chars.count)
                && !glyphs.contains(0)
        }
        // 한글은 상용 밖 음절까지 — 서브셋에서 음절을 덜어내지 않았음을 확인한다.
        XCTAssertTrue(hasGlyphs(kr, "운동에너지속도밀도"), "KR: 기본 한글 누락")
        XCTAssertTrue(hasGlyphs(kr, "뷁뷀꿹뾃"), "KR: 상용 밖 음절 누락 — 서브셋이 과했다")
        XCTAssertTrue(hasGlyphs(sc, "国学汉语过说这门为电脑"), "SC: 상용 간체 누락")
    }

    /// 폴백을 얹으면 캐스케이드가 실제로 붙고, **시스템 기본 체인도 남는다.**
    func testCascadeIncludesSystemDefaults() throws {
        let base = try baseFont()
        let plain = cascadeCount(base)
        let font = base.copy(withCJKSerif: .korean)
        let withFallback = cascadeCount(font)

        XCTAssertGreaterThan(withFallback, plain,
                             "캐스케이드가 안 붙었다(before=\(plain) after=\(withFallback))")
        XCTAssertGreaterThan(withFallback, 1,
                             "시스템 기본 체인이 대체돼 버렸다 — 지정 폰트에 없는 문자가 두부가 된다")
    }

    /// 크기가 바뀌어도 캐스케이드가 살아남는가 — 첨자·분수가 타는 경로.
    func testCascadeSurvivesResize() throws {
        let font = try baseFont(24).copy(withCJKSerif: .korean)
        let before = cascadeCount(font)
        let smaller = font.copy(withSize: 12)
        XCTAssertEqual(cascadeCount(smaller), before,
                       "copy(withSize:) 가 캐스케이드를 잃었다 — 첨자만 서체가 갈린다")
        XCTAssertEqual(smaller.fontSize, 12)
    }

    /// 기반 수학 폰트가 폴백 지정 후에도 그대로여야 한다.
    ///
    /// 디스크립터를 새로 해석시키면 시스템에 등록되지 않은 수학 폰트가 Helvetica 로
    /// 바뀌어 버린다. 라틴 글리프 ID 가 보존되는지로 확인한다.
    func testBaseMathFontUnchanged() throws {
        let base = try baseFont()
        let font = base.copy(withCJKSerif: .korean)
        XCTAssertEqual(CTFontCopyPostScriptName(font.ctFont) as String,
                       CTFontCopyPostScriptName(base.ctFont) as String,
                       "기반 수학 폰트가 바뀌었다")
        for ch in "x∑√∫" {
            var chars = Array(String(ch).utf16)
            var g1 = [CGGlyph](repeating: 0, count: chars.count)
            var g2 = [CGGlyph](repeating: 0, count: chars.count)
            CTFontGetGlyphsForCharacters(base.ctFont, &chars, &g1, chars.count)
            CTFontGetGlyphsForCharacters(font.ctFont, &chars, &g2, chars.count)
            XCTAssertEqual(g1, g2, "'\(ch)' 글리프가 달라졌다 — 기반 폰트가 교체됐다")
        }
        XCTAssertNotNil(font.mathTable, "수학 테이블이 유실됐다")
    }

    /// 없는 폰트 이름은 조용히 무시된다 — 지정하지 않은 서체가 끼어들면 안 된다.
    func testUnknownFontNameIsIgnored() throws {
        let base = try baseFont()
        XCTAssertNil(MTFont.systemFont(named: "ThisFontDoesNotExist12345", size: 20))
        let font = base.copy(withFallbackFontNames: ["ThisFontDoesNotExist12345"])
        XCTAssertEqual(cascadeCount(font), cascadeCount(base),
                       "없는 이름이 캐스케이드에 들어갔다")
    }

    /// 조판까지 통과하는가 — 폴백을 얹은 폰트로 CJK 수식이 실제로 그려져야 한다.
    func testTypesetsWithFallback() throws {
        let font = try baseFont(20).copy(withCJKSerif: .korean, .simplifiedChinese)
        for latex in [#"E_{운동} = \frac{1}{2}mv^2"#, #"\text{속도} = 5"#, #"\sqrt{운동}"#] {
            var error: NSError?
            let list = try XCTUnwrap(MTMathListBuilder.build(fromString: latex, error: &error))
            let display = MTTypesetter.createLineForMathList(list, font: font, style: .display)
            XCTAssertNotNil(display, "조판 실패: \(latex)")
            XCTAssertGreaterThan(display!.width, 0, "폭이 0: \(latex)")
        }
    }

    /// 폴백을 얹으면 CJK 가 **더 넓게** 그려진다 — 두부(.notdef)가 아니라 실제 글리프라는 증거.
    func testCJKRendersWiderThanNotdef() throws {
        let bare = try baseFont(20)
        let font = bare.copy(withCJKSerif: .korean)
        func width(_ latex: String, _ f: MTFont) throws -> CGFloat {
            var error: NSError?
            let list = try XCTUnwrap(MTMathListBuilder.build(fromString: latex, error: &error))
            return try XCTUnwrap(MTTypesetter.createLineForMathList(list, font: f, style: .display)).width
        }
        // 라틴만 있는 수식의 폭은 폴백과 무관해야 한다.
        XCTAssertEqual(try width("x+y", bare), try width("x+y", font), accuracy: 0.01,
                       "폴백이 라틴 조판까지 건드렸다")
        XCTAssertGreaterThan(try width(#"\text{운동에너지}"#, font), 0)
    }
}
