import XCTest
@testable import SwiftMath

/// Tier 3 — mhchem(`\ce`)과 siunitx(`\SI`) 서브셋.
///
/// 둘 다 LaTeX 가 아닌 별도 문법이라 일반 LaTeX 로 옮겨 기존 파서에 태운다.
/// 그래서 검증도 두 층이다 — ① 옮긴 결과가 맞는가 ② 그게 실제로 조판되는가.
final class ScienceNotationTests: XCTestCase {

    private func display(_ latex: String, size: CGFloat = 20,
                         file: StaticString = #filePath, line: UInt = #line) throws -> MTMathListDisplay {
        var error: NSError?
        let list = MTMathListBuilder.build(fromString: latex, error: &error)
        XCTAssertNil(error, "파싱 오류 (\(latex)): \(error?.localizedDescription ?? "")", file: file, line: line)
        let font = try XCTUnwrap(MTFontManager.fontManager.latinModernFont(withSize: size), file: file, line: line)
        return try XCTUnwrap(MTTypesetter.createLineForMathList(try XCTUnwrap(list, file: file, line: line),
                                                               font: font, style: .display),
                             "조판 실패: \(latex)", file: file, line: line)
    }

    // MARK: - mhchem 변환

    func testSubscriptsAfterElements() {
        XCTAssertEqual(MTChemFormula.toLatex("H2O"), #"\text{H}_{2}\text{O}"#)
        XCTAssertEqual(MTChemFormula.toLatex("H2SO4"), #"\text{H}_{2}\text{S}\text{O}_{4}"#)
    }

    /// 앞에 오는 숫자는 계수라 보통 크기, 뒤에 오는 숫자만 아래첨자다.
    func testLeadingCoefficientIsNotSubscript() {
        XCTAssertEqual(MTChemFormula.toLatex("2H2O"), #"2\text{H}_{2}\text{O}"#)
    }

    /// 두 글자 원소 기호(Ca, Cl, Na)를 한 덩이로 읽는다.
    func testTwoLetterElements() {
        XCTAssertEqual(MTChemFormula.toLatex("NaCl"), #"\text{Na}\text{Cl}"#)
        XCTAssertEqual(MTChemFormula.toLatex("CaCO3"), #"\text{Ca}\text{C}\text{O}_{3}"#)
    }

    /// 전하의 빼기는 하이픈이 아니라 마이너스여야 한다.
    func testChargeUsesMinusSign() {
        XCTAssertEqual(MTChemFormula.toLatex("SO4^2-"), "\\text{S}\\text{O}_{4}^{2\u{2212}}")
        XCTAssertEqual(MTChemFormula.toLatex("Ca^2+"), #"\text{Ca}^{2+}"#)
    }

    func testStateLabels() {
        XCTAssertEqual(MTChemFormula.toLatex("NaCl(aq)"), #"\text{Na}\text{Cl}\text{(aq)}"#)
        for state in ["(s)", "(l)", "(g)"] {
            XCTAssertTrue(MTChemFormula.toLatex("X\(state)").contains("\\text{\(state)}"))
        }
    }

    func testArrows() {
        XCTAssertTrue(MTChemFormula.toLatex("A -> B").contains("\\longrightarrow"))
        XCTAssertTrue(MTChemFormula.toLatex("A <- B").contains("\\longleftarrow"))
        XCTAssertTrue(MTChemFormula.toLatex("A <=> B").contains("\\rightleftharpoons"))
        XCTAssertTrue(MTChemFormula.toLatex("A <-> B").contains("\\longleftrightarrow"))
    }

    /// 라벨이 붙으면 늘어나는 화살표를 쓴다. 첫 대괄호가 위, 둘째가 아래다.
    func testArrowLabels() {
        XCTAssertTrue(MTChemFormula.toLatex("A ->[촉매] B").contains(#"\xrightarrow{\text{촉매}}"#))
        let both = MTChemFormula.toLatex("A ->[위][아래] B")
        XCTAssertTrue(both.contains(#"\xrightarrow[\text{아래}]{\text{위}}"#), both)
    }

    /// 붙은 `+` 는 전하, 띄운 `+` 는 구분자다. 실제 교재(OpenStax 유기화학 63쪽)의
    /// `\ce{H3PO4 <=> H2PO4^- + H+}` 에서 둘이 한 줄에 같이 나온다.
    func testAttachedPlusIsChargeSpacedPlusIsSeparator() {
        XCTAssertEqual(MTChemFormula.toLatex("H+"), #"\text{H}^{+}"#)
        XCTAssertEqual(MTChemFormula.toLatex("Na+"), #"\text{Na}^{+}"#)
        let mixed = MTChemFormula.toLatex("H2PO4^- + H+")
        XCTAssertTrue(mixed.contains(" + "), "띄운 +가 구분자로 안 나왔다: \(mixed)")
        XCTAssertTrue(mixed.hasSuffix("^{+}"), "붙은 +가 전하로 안 나왔다: \(mixed)")
    }

    /// 결합선 `=` 는 관계연산자가 아니다 — 원자에 바짝 붙어야 한다.
    func testDoubleBondIsTight() throws {
        let bond = try display(#"\ce{CH2=CH2}"#)
        let relation = try display(#"\text{CH}_2 = \text{CH}_2"#)
        XCTAssertLessThan(bond.width, relation.width,
                          "이중결합에 관계연산자 간격이 붙었다")
    }

    func testHydrateDot() {
        XCTAssertTrue(MTChemFormula.toLatex("CuSO4*5H2O").contains("\\cdot"))
    }

    /// 홀로 선 `v` 는 침전, `^` 는 기체 발생 표시다.
    func testPrecipitateAndGasArrows() {
        XCTAssertTrue(MTChemFormula.toLatex("AgCl v").contains("\\downarrow"))
        XCTAssertTrue(MTChemFormula.toLatex("H2 ^").contains("\\uparrow"))
        // 전하로 쓰인 `^` 는 화살표가 아니다.
        XCTAssertFalse(MTChemFormula.toLatex("Ca^2+").contains("\\uparrow"))
        // 원소 이름 속 v 는 화살표가 아니다.
        XCTAssertFalse(MTChemFormula.toLatex("V2O5").contains("\\downarrow"))
    }

    func testIsotopeNotation() {
        let out = MTChemFormula.toLatex("^{227}_{90}Th")
        XCTAssertTrue(out.contains("^{227}"), out)
        XCTAssertTrue(out.contains("_{90}"), out)
        XCTAssertTrue(out.contains(#"\text{Th}"#), out)
    }

    // MARK: - mhchem 조판

    func testChemistryFormulasTypeset() throws {
        for latex in [#"\ce{H2O}"#, #"\ce{H2SO4}"#, #"\ce{2H2 + O2 -> 2H2O}"#,
                      #"\ce{N2 + 3H2 <=> 2NH3}"#, #"\ce{CuSO4*5H2O}"#,
                      #"\ce{NaCl(aq) + AgNO3(aq) -> AgCl v + NaNO3(aq)}"#,
                      #"\ce{Fe^{3+} + 3OH^- -> Fe(OH)3}"#,
                      #"\ce{CH4 + 2O2 ->[점화] CO2 + 2H2O}"#] {
            let d = try display(latex)
            XCTAssertGreaterThan(d.width, 0, "폭이 0: \(latex)")
        }
    }

    /// 반응식이 화살표 때문에 넓어진다 — 화살표가 실제로 그려진다는 증거.
    func testReactionArrowTakesSpace() throws {
        let withArrow = try display(#"\ce{A -> B}"#)
        let without = try display(#"\ce{A B}"#)
        XCTAssertGreaterThan(withArrow.width, without.width)
    }

    /// 아래첨자가 실제로 조판된다.
    func testSubscriptIsTypeset() throws {
        let sub = try display(#"\ce{H2O}"#)
        let flat = try display(#"\ce{HO}"#)
        XCTAssertGreaterThan(sub.width, flat.width, "아래첨자가 안 그려졌다")
    }

    // MARK: - siunitx 변환

    func testUnitBasics() {
        XCTAssertEqual(MTUnitNotation.toLatex(value: "3", unit: #"\meter"#), #"3\,\text{m}"#)
        XCTAssertEqual(MTUnitNotation.units(#"\kilo\gram"#), #"\text{k}\text{g}"#)
    }

    func testPerAndPowers() {
        XCTAssertEqual(MTUnitNotation.units(#"\meter\per\second\squared"#),
                       #"\text{m}/\text{s}^{2}"#)
        XCTAssertTrue(MTUnitNotation.units(#"\meter\cubed"#).contains("^{3}"))
    }

    func testScientificNotation() {
        XCTAssertEqual(MTUnitNotation.number("1.5e3"), #"1.5 \times 10^{3}"#)
        XCTAssertTrue(MTUnitNotation.number("6.022e23").contains(#"10^{23}"#))
        // 지수가 아닌 값은 그대로.
        XCTAssertEqual(MTUnitNotation.number("42"), "42")
        // 음수 지수의 빼기는 마이너스여야 한다.
        XCTAssertTrue(MTUnitNotation.number("1e-5").contains("\u{2212}5"))
    }

    /// 매크로가 아니라 기호를 직접 쓴 경우도 받는다.
    func testLiteralUnits() {
        XCTAssertEqual(MTUnitNotation.units("km"), #"\text{km}"#)
    }

    /// 모르는 단위 매크로는 이름을 보여 준다 — 사라지는 것보다 낫다.
    func testUnknownUnitIsShownNotDropped() {
        let out = MTUnitNotation.units(#"\furlong"#)
        XCTAssertTrue(out.contains("furlong"), out)
    }

    // MARK: - siunitx 조판

    func testUnitsTypeset() throws {
        for latex in [#"\SI{3}{\meter}"#, #"\SI{9.8}{\meter\per\second\squared}"#,
                      #"\SI{1.5e3}{\kilo\gram}"#, #"\SI{25}{\celsius}"#,
                      #"\SI{6.022e23}{\per\mole}"#, #"\SI{100}{\percent}"#,
                      #"\si{\ohm}"#, #"\num{2.5e-3}"#, #"\SIrange{1}{10}{\meter}"#] {
            let d = try display(latex)
            XCTAssertGreaterThan(d.width, 0, "폭이 0: \(latex)")
        }
    }

    /// 값과 단위 사이에 얇은 공백이 들어간다.
    func testThinSpaceBetweenValueAndUnit() throws {
        let spaced = try display(#"\SI{3}{\meter}"#)
        let jammed = try display(#"3\text{m}"#)
        XCTAssertGreaterThan(spaced.width, jammed.width, "값과 단위가 붙어 있다")
    }

    // MARK: - 섞어 쓰기 · 실패 처리

    func testMixedWithMathAndCJK() throws {
        for latex in [#"\text{반응}: \ce{2H2 + O2 -> 2H2O}"#,
                      #"v = \SI{9.8}{\meter\per\second\squared}"#,
                      #"\boxed{\ce{H2O}}"#,
                      #"\frac{\ce{H2}}{\ce{O2}}"#,
                      #"\ce{H2O} \text{는 물이다}"#] {
            let d = try display(latex)
            XCTAssertGreaterThan(d.width, 0, "폭이 0: \(latex)")
        }
    }

    /// 옮길 수 없는 입력이라도 **내용을 잃지 않는다** — 정립 텍스트로 흘려보낸다.
    func testMalformedFallsBackToText() throws {
        for latex in [#"\ce{}"#, #"\ce{???}"#, #"\SI{}{}"#, #"\si{}"#] {
            var error: NSError?
            let list = MTMathListBuilder.build(fromString: latex, error: &error)
            XCTAssertNotNil(list, "\(latex) 가 통째로 실패했다")
        }
    }

    func testMissingBraceDoesNotCrash() {
        for latex in [#"\ce"#, #"\ce{H2O"#, #"\SI{3}"#, #"\SI"#, #"\num{"#] {
            var error: NSError?
            if let list = MTMathListBuilder.build(fromString: latex, error: &error),
               let font = MTFontManager.fontManager.latinModernFont(withSize: 20) {
                _ = MTTypesetter.createLineForMathList(list, font: font, style: .display)
            }
        }
    }
}
