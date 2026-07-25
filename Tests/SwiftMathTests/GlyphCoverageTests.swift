import XCTest
import CoreText
@testable import SwiftMath

/// 심볼 테이블의 모든 코드포인트가 **수학 폰트 자체**에 있는지 검사한다.
///
/// 왜 필요한가: 폰트에 없는 코드포인트를 테이블에 넣어도 파싱은 성공하고 렌더도 "된다".
/// CoreText가 시스템 캐스케이드로 CJK 폰트 등에 떨어뜨려 **전각(1em) 글리프**를 그리기
/// 때문이다. 즉 실패가 눈에 띄는 오류가 아니라 조용한 오조판으로 나타난다 — 수식 한복판에
/// 혼자 거대한 기호가 박힌다. 테이블을 넓힐 때 이 테스트가 유일한 안전장치다.
final class GlyphCoverageTests: XCTestCase {

    /// 이 문자열의 모든 스칼라가 수학 폰트에 글리프를 갖는가(캐스케이드 없이 직접 조회).
    ///
    /// 스칼라 단위로 조회하는 이유: CTFontGetGlyphsForCharacters는 UTF-16 배열을 받는데,
    /// BMP 밖 문자(U+1D715 \partial 등)는 서로게이트 **쌍**으로 들어가고 글리프는 상위
    /// 서로게이트 자리에만 채워지며 하위 자리는 0으로 남는다. 배열에 0이 있는지로 판정하면
    /// 멀쩡한 문자가 전부 '누락'으로 잡힌다(실제로 \partial·\phi·\epsilon 등 8개가 거짓
    /// 양성이었다).
    private func mathFontHasGlyph(_ s: String, font: MTFont) -> Bool {
        guard !s.unicodeScalars.isEmpty else { return false }
        for scalar in s.unicodeScalars {
            var units = Array(String(scalar).utf16)
            var glyphs = [CGGlyph](repeating: 0, count: units.count)
            let found = CTFontGetGlyphsForCharacters(font.ctFont, &units, &glyphs, units.count)
            // 상위 서로게이트(=첫 자리)의 글리프만 유효하다.
            if !found || glyphs.first == 0 { return false }
        }
        return true
    }

    /// 조판에 관여하지 않는(또는 폰트 글리프를 요구하지 않는) 원자 타입.
    private func requiresGlyph(_ atom: MTMathAtom) -> Bool {
        if atom is MTMathSpace { return false }
        if atom is MTMathStyle { return false }
        if atom.type == .placeholder { return false }
        // 결합용 악센트는 단독 조회가 의미 없다(악센트 테이블에서 따로 다룬다).
        return !atom.nucleus.isEmpty
    }

    /// latinmodern-math 에 글리프가 없는 **기존(upstream) 심볼**. 우리가 만든 갭이 아니라
    /// 물려받은 것이라 제거하지 않고(동작 변경 회피) 여기 명시해 둔다. 목적은 "새로 추가하는
    /// 심볼"에 대해서만 검사를 엄격히 유지하는 것이다 — 이 목록이 늘어나면 회귀다.
    /// 전부 희귀한 부정/근사 관계자라 한국 학부 STEM 자료에서 사실상 쓰이지 않는다.
    private static let knownMissingUpstream: Set<String> = [
        "doublebarwedge", "lbar",
        "precnapprox", "precneqq", "succnapprox", "succneqq",
        "subsetneqq", "supsetneqq", "varsubsetneqq", "varsupsetneqq",
    ]

    func testAllSymbolsHaveGlyphsInMathFont() throws {
        let font = try XCTUnwrap(MTFontManager.fontManager.latinModernFont(withSize: 20))

        var missing: [String] = []
        var unexpectedlyPresent: [String] = []
        for (name, atom) in MTMathAtomFactory.supportedLatexSymbols {
            guard requiresGlyph(atom) else { continue }
            let hasGlyph = mathFontHasGlyph(atom.nucleus, font: font)
            if !hasGlyph && !Self.knownMissingUpstream.contains(name) {
                let cp = atom.nucleus.unicodeScalars
                    .map { String(format: "U+%04X", $0.value) }.joined(separator: " ")
                missing.append("\\\(name) (\(cp))")
            }
            if hasGlyph && Self.knownMissingUpstream.contains(name) {
                unexpectedlyPresent.append(name)
            }
        }

        XCTAssertTrue(missing.isEmpty, """
            latinmodern-math 에 글리프가 없는 심볼 \(missing.count)개 — 시스템 폰트 캐스케이드로
            전각 오조판이 된다. 테이블에서 빼거나 폰트 캐스케이드를 먼저 도입할 것:
            \(missing.sorted().joined(separator: ", "))
            """)
        XCTAssertTrue(unexpectedlyPresent.isEmpty,
                      "knownMissingUpstream 이 낡았다 — 글리프가 생긴 항목: \(unexpectedlyPresent.sorted())")
    }

    /// aliases 는 canonical 이름을 가리켜야 하고, 그 canonical 이 실제로 존재해야 한다.
    func testAliasesResolveToExistingSymbols() {
        var broken: [String] = []
        for (alias, canonical) in MTMathAtomFactory.aliases {
            let resolvesToSymbol = MTMathAtomFactory.supportedLatexSymbols[canonical] != nil
            let resolvesToDelimiter = MTMathAtomFactory.delimiters[canonical] != nil
            if !resolvesToSymbol && !resolvesToDelimiter {
                broken.append("\\\(alias) → \\\(canonical)")
            }
        }
        XCTAssertTrue(broken.isEmpty, "존재하지 않는 대상을 가리키는 별칭: \(broken.sorted())")
    }

    /// 악센트도 결합 문자 글리프가 필요하다.
    func testAccentsHaveGlyphs() throws {
        let font = try XCTUnwrap(MTFontManager.fontManager.latinModernFont(withSize: 20))
        var missing: [String] = []
        for (name, value) in MTMathAtomFactory.accents {
            if !mathFontHasGlyph(value, font: font) {
                let cp = value.unicodeScalars.map { String(format: "U+%04X", $0.value) }.joined()
                missing.append("\\\(name) (\(cp))")
            }
        }
        XCTAssertTrue(missing.isEmpty, "글리프 없는 악센트: \(missing.sorted())")
    }
}
