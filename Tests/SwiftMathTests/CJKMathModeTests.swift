import XCTest
@testable import SwiftMath

/// Non-ASCII (CJK) content inside *math* mode — not just inside \text{}.
///
/// Upstream added a fallback-font path so `\text{속도}` works, but bare math mode still
/// dropped the characters: "속도 = 5" typeset as "=5" and "v_{초기}" as "v_{}". The content
/// disappeared with no error, which is the worst failure mode — neither the user nor the
/// caller can detect it. These tests pin the fix.
final class CJKMathModeTests: XCTestCase {

    private func roundTrip(_ latex: String, file: StaticString = #filePath, line: UInt = #line) -> String {
        var err: NSError? = nil
        guard let list = MTMathListBuilder.build(fromString: latex, error: &err) else {
            XCTFail("parse failed: \(err?.localizedDescription ?? "unknown")", file: file, line: line)
            return ""
        }
        return MTMathListBuilder.mathListToString(list)
    }

    // MARK: - Content preservation

    func testKoreanSurvivesBareMathMode() {
        XCTAssertEqual(roundTrip("속도 = 5"), "속도=5")
    }

    func testKoreanSurvivesInSubscript() {
        // The regression that motivated this: v_{초기} used to collapse to v_{}.
        XCTAssertEqual(roundTrip("v_{초기}"), "v_{초기}")
    }

    func testJapaneseAndChineseSurvive() {
        XCTAssertEqual(roundTrip("速度 = 5"), "速度=5")
        XCTAssertEqual(roundTrip("かな"), "かな")
    }

    func testMixedScriptExpression() {
        // Round-trip normalises single-character scripts to braced form (x^2 -> x^{2});
        // what matters here is that the Korean subscript survives intact.
        XCTAssertEqual(roundTrip("E_{운동} = \\frac{1}{2}mv^2"),
                       "E_{운동}=\\frac{1}{2}mv^{2}")
    }

    func testTextModeStillWorks() {
        // Upstream behaviour must be preserved.
        XCTAssertEqual(roundTrip("\\text{속도}"), "\\mathrm{속도}")
    }

    // MARK: - No collateral damage to ASCII/LaTeX semantics

    func testAsciiMathUnchanged() {
        // Scripts are normalised to braced form by the round-trip; structure is otherwise intact.
        XCTAssertEqual(roundTrip("x^2 + y_1 = \\frac{a}{b}"), "x^{2}+y_{1}=\\frac{a}{b}")
    }

    func testAsciiControlCharactersAreStillNotOrdinaryAtoms() {
        // The new branch is gated on > 0x7E, so ASCII characters with LaTeX meaning keep their
        // existing treatment (ignored/handled) rather than becoming literal glyphs.
        XCTAssertEqual(roundTrip("a # b"), "ab")
        XCTAssertEqual(roundTrip("a % b"), "ab")
    }

    // MARK: - Actually renders (parse success alone is not enough)

    func testKoreanMathModeProducesImage() throws {
        var image = MTMathImage(latex: "속도 = 5", fontSize: 20, textColor: MTColor.black)
        let (error, rendered) = image.asImage()
        XCTAssertNil(error, "render error: \(String(describing: error))")
        let img = try XCTUnwrap(rendered, "no image produced")
        // A dropped-glyph render collapses to roughly the width of "=5"; the Korean run must
        // make it materially wider. Compare against the same expression without the Korean.
        var bare = MTMathImage(latex: "= 5", fontSize: 20, textColor: MTColor.black)
        let (_, bareRendered) = bare.asImage()
        let bareWidth = try XCTUnwrap(bareRendered).size.width
        XCTAssertGreaterThan(img.size.width, bareWidth + 10,
                             "Korean glyphs do not appear to be rendered (width \(img.size.width) vs \(bareWidth))")
    }

    // MARK: - Script alphabet

    func testMathscrParses() {
        XCTAssertEqual(roundTrip("\\mathscr{E}"), "\\mathcal{E}")
    }

    func testScriptAliasesParse() {
        for cmd in ["scr", "pmb", "mathds", "mathsfit"] {
            var err: NSError? = nil
            XCTAssertNotNil(MTMathListBuilder.build(fromString: "\\\(cmd){A}", error: &err),
                            "\\\(cmd) should parse: \(err?.localizedDescription ?? "")")
        }
    }
}
