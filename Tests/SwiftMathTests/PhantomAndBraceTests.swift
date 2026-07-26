import XCTest
@testable import SwiftMath

/// Tier 1 — `\phantom` 계열, `\mathstrut`, `\idotsint`, `\overbrace`/`\underbrace`.
final class PhantomAndBraceTests: XCTestCase {

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

    // MARK: - phantom 계열

    /// \phantom 은 자리를 그대로 차지한다 — 폭·높이 모두 내용과 같다.
    func testPhantomKeepsAllDimensions() throws {
        let real = try display("x+y")
        let ghost = try display(#"\phantom{x+y}"#)
        XCTAssertEqual(ghost.width, real.width, accuracy: 0.01, "폭이 다르다")
        XCTAssertEqual(ghost.ascent, real.ascent, accuracy: 0.01, "높이가 다르다")
        XCTAssertEqual(ghost.descent, real.descent, accuracy: 0.01, "깊이가 다르다")
    }

    /// \hphantom 은 폭만 남긴다.
    func testHorizontalPhantomKeepsWidthOnly() throws {
        let real = try display("x+y")
        let ghost = try display(#"\hphantom{x+y}"#)
        XCTAssertEqual(ghost.width, real.width, accuracy: 0.01)
        XCTAssertEqual(ghost.ascent, 0, accuracy: 0.01, "높이가 남았다")
        XCTAssertEqual(ghost.descent, 0, accuracy: 0.01, "깊이가 남았다")
    }

    /// \vphantom 은 높이만 남긴다.
    func testVerticalPhantomKeepsHeightOnly() throws {
        let real = try display(#"\frac{a}{b}"#)
        let ghost = try display(#"\vphantom{\frac{a}{b}}"#)
        XCTAssertEqual(ghost.width, 0, accuracy: 0.01, "폭이 남았다")
        XCTAssertEqual(ghost.ascent, real.ascent, accuracy: 0.01)
        XCTAssertEqual(ghost.descent, real.descent, accuracy: 0.01)
    }

    /// \smash 는 폭을 남기고 높이만 0으로 신고한다 — 내용은 그린다.
    func testSmashKeepsWidthDropsHeight() throws {
        let real = try display(#"\frac{a}{b}"#)
        let smashed = try display(#"\smash{\frac{a}{b}}"#)
        XCTAssertEqual(smashed.width, real.width, accuracy: 0.01)
        XCTAssertEqual(smashed.ascent, 0, accuracy: 0.01)
        XCTAssertEqual(smashed.descent, 0, accuracy: 0.01)
    }

    /// \mathstrut 은 인자 없이 여는 괄호 높이의 버팀목이다.
    func testMathstrut() throws {
        let strut = try display(#"\mathstrut"#)
        let paren = try display("(")
        XCTAssertEqual(strut.width, 0, accuracy: 0.01, "버팀목이 폭을 차지한다")
        XCTAssertEqual(strut.ascent, paren.ascent, accuracy: 0.01, "여는 괄호 높이가 아니다")
    }

    /// phantom 이 실제로 줄을 맞추는 데 쓸 수 있는가 — 나란히 놓으면 폭이 두 배.
    func testPhantomUsableForAlignment() throws {
        let single = try display("x")
        let padded = try display(#"\phantom{x}x"#)
        XCTAssertEqual(padded.width, single.width * 2, accuracy: 0.5)
    }

    // MARK: - \idotsint

    func testIdotsint() throws {
        let d = try display(#"\idotsint f"#)
        XCTAssertGreaterThan(d.width, 0)
        // ∫ 하나보다는 확실히 넓어야 한다(∫⋯∫ 세 글자).
        let single = try display(#"\int f"#)
        XCTAssertGreaterThan(d.width, single.width, "∫⋯∫ 가 ∫ 하나보다 좁다")
    }

    // MARK: - \overbrace / \underbrace

    func testOverbraceParses() throws {
        var error: NSError?
        let list = try XCTUnwrap(MTMathListBuilder.build(fromString: #"\overbrace{a+b}"#, error: &error))
        XCTAssertNil(error)
        let atom = try XCTUnwrap(list.atoms.first as? MTUnderOver)
        XCTAssertEqual(atom.stretchyOver, "\u{23DE}")
        XCTAssertNil(atom.stretchyUnder)
    }

    /// 중괄호가 위쪽 높이를 늘린다.
    func testOverbraceAddsHeight() throws {
        let bare = try display("a+b")
        let braced = try display(#"\overbrace{a+b}"#)
        XCTAssertGreaterThan(braced.ascent, bare.ascent, "중괄호가 안 그려졌다")
        XCTAssertEqual(braced.descent, bare.descent, accuracy: 0.5, "위 장식인데 아래로 자랐다")
    }

    func testUnderbraceAddsDepth() throws {
        let bare = try display("a+b")
        let braced = try display(#"\underbrace{a+b}"#)
        XCTAssertGreaterThan(braced.descent, bare.descent, "중괄호가 안 그려졌다")
        XCTAssertEqual(braced.ascent, bare.ascent, accuracy: 0.5)
    }

    /// **중괄호가 내용 폭을 따라 늘어나는가** — 이게 이 기능의 핵심이다.
    func testBraceStretchesToContent() throws {
        let narrow = try display(#"\overbrace{ab}"#)
        let wide = try display(#"\overbrace{a+b+c+d+e+f}"#)
        XCTAssertGreaterThan(wide.width, narrow.width * 2,
                             "내용이 늘었는데 폭이 안 따라왔다")
        // 폭이 내용과 같아야 한다(중괄호가 내용보다 좁거나 넓으면 안 된다).
        let content = try display("a+b+c+d+e+f")
        XCTAssertEqual(wide.width, content.width, accuracy: 1.0,
                       "중괄호 폭이 내용과 어긋난다")
    }

    /// 뒤따르는 첨자는 중괄호 **위 가운데**로 간다(오른쪽 위 첨자가 아니다).
    func testLabelIsAbsorbedAsCenteredLabel() throws {
        var error: NSError?
        let list = try XCTUnwrap(MTMathListBuilder.build(
            fromString: #"\overbrace{a+b}^{n\text{개}}"#, error: &error))
        XCTAssertNil(error)
        let atom = try XCTUnwrap(list.atoms.first as? MTUnderOver)
        XCTAssertNotNil(atom.over, "라벨을 못 삼켰다")
        XCTAssertNil(atom.superScript, "라벨이 일반 첨자로 남았다")
    }

    func testLabelAddsMoreHeight() throws {
        let plain = try display(#"\overbrace{a+b}"#)
        let labelled = try display(#"\overbrace{a+b}^{n}"#)
        XCTAssertGreaterThan(labelled.ascent, plain.ascent, "라벨이 중괄호 위에 안 얹혔다")
    }

    func testUnderbraceLabel() throws {
        let plain = try display(#"\underbrace{a+b}"#)
        let labelled = try display(#"\underbrace{a+b}_{n}"#)
        XCTAssertGreaterThan(labelled.descent, plain.descent)
    }

    /// 엉뚱한 방향의 첨자는 삼키지 않는다 — `\overbrace{x}_{y}` 의 `_` 는 일반 첨자다.
    func testWrongDirectionScriptIsNotAbsorbed() throws {
        var error: NSError?
        let list = try XCTUnwrap(MTMathListBuilder.build(fromString: #"\overbrace{a}_{n}"#, error: &error))
        XCTAssertNil(error)
        let atom = try XCTUnwrap(list.atoms.first as? MTUnderOver)
        XCTAssertNil(atom.under, "아래 라벨로 잘못 삼켰다")
        XCTAssertNotNil(atom.subScript, "일반 아래첨자로 남지 않았다")
    }

    // MARK: - CJK · 조합

    func testCJKAndNesting() throws {
        for latex in [#"\overbrace{속도 + 가속도}^{\text{운동학}}"#,
                      #"\underbrace{질량 \times 부피}_{\text{밀도}}"#,
                      #"\overbrace{\frac{a}{b}}"#,
                      #"\phantom{속도}가속도"#,
                      #"\boxed{\overbrace{a+b}^{합}}"#] {
            let d = try display(latex)
            XCTAssertGreaterThan(d.width, 0, "폭이 0: \(latex)")
        }
    }

    func testRoundTrip() throws {
        for latex in [#"\overbrace{a+b}"#, #"\underbrace{a+b}"#,
                      #"\phantom{x}"#, #"\smash{x}"#] {
            var error: NSError?
            let list = try XCTUnwrap(MTMathListBuilder.build(fromString: latex, error: &error))
            let out = MTMathListBuilder.mathListToString(list)
            var reError: NSError?
            XCTAssertNotNil(MTMathListBuilder.build(fromString: out, error: &reError),
                            "되돌린 문자열을 다시 못 읽는다: \(out)")
            XCTAssertNil(reError, "재파싱 오류 (\(out)): \(reError?.localizedDescription ?? "")")
        }
    }

    func testMalformedDoesNotCrash() {
        for latex in [#"\overbrace"#, #"\overbrace{"#, #"\phantom"#, #"\smash{"#,
                      #"\overbrace{a}^"#, #"\vphantom"#] {
            var error: NSError?
            if let list = MTMathListBuilder.build(fromString: latex, error: &error),
               let font = MTFontManager.fontManager.latinModernFont(withSize: 20) {
                _ = MTTypesetter.createLineForMathList(list, font: font, style: .display)
            }
        }
    }
}
