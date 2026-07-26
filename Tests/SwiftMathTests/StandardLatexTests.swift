import XCTest
@testable import SwiftMath

/// 표준 LaTeX 인데 빠져 있던 것들. 카테고리별로 훑어 찾은 결과를 회귀로 굳힌다.
final class StandardLatexTests: XCTestCase {

    private func build(_ latex: String, file: StaticString = #filePath, line: UInt = #line) throws -> MTMathList {
        var error: NSError?
        let list = MTMathListBuilder.build(fromString: latex, error: &error)
        XCTAssertNil(error, "파싱 오류 (\(latex)): \(error?.localizedDescription ?? "")", file: file, line: line)
        return try XCTUnwrap(list, file: file, line: line)
    }

    private func display(_ latex: String, file: StaticString = #filePath, line: UInt = #line) throws -> MTMathListDisplay {
        let font = try XCTUnwrap(MTFontManager.fontManager.latinModernFont(withSize: 20), file: file, line: line)
        return try XCTUnwrap(MTTypesetter.createLineForMathList(try build(latex, file: file, line: line),
                                                               font: font, style: .display),
                             "조판 실패: \(latex)", file: file, line: line)
    }

    /// `\not` 은 `\command` 만 보고 있어서 `\not=` 가 실패했다. `\neq` 만큼 흔한 표기다.
    func testNotWithBareCharacter() throws {
        for (latex, expected) in [(#"a \not= b"#, "\u{2260}"), (#"a \not< b"#, "\u{226E}"),
                                  (#"a \not> b"#, "\u{226F}")] {
            let list = try build(latex)
            XCTAssertTrue(list.atoms.contains { $0.nucleus == expected },
                          "\(latex) 가 부정 기호를 안 만들었다")
        }
        // 기존 \not\command 형태도 그대로 동작해야 한다.
        XCTAssertNoThrow(try build(#"x \not\in A"#))
    }

    /// 표준 텍스트 명령 9종. 이 조판기에 없는 서체는 가장 가까운 것으로 떨어뜨린다.
    func testTextCommands() throws {
        for command in ["textnormal", "textup", "textmd", "mbox", "textsc",
                        "textsl", "emph", "texttt", "textrm"] {
            XCTAssertGreaterThan(try display("\\\(command){abc}").width, 0, "\\\(command) 실패")
        }
        // \ensuremath 는 서체를 안 바꾸고 인자를 그대로 낸다.
        XCTAssertEqual(try display(#"\ensuremath{x+y}"#).width,
                       try display("x+y").width, accuracy: 0.01)
    }

    /// amsmath 의 이탤릭 대문자 그리스.
    func testItalicCapitalGreek() throws {
        for command in ["varGamma", "varDelta", "varTheta", "varLambda", "varXi",
                        "varPi", "varSigma", "varUpsilon", "varPhi", "varPsi", "varOmega"] {
            XCTAssertGreaterThan(try display("\\\(command)").width, 0, "\\\(command) 실패")
        }
    }

    /// 명시적 간격. mu 로 환산해 넣는다.
    func testExplicitSpacing() throws {
        for latex in [#"a \hspace{1cm} b"#, #"a \kern 5pt b"#, #"a \mkern 18mu b"#,
                      #"a \hskip 3pt b"#, #"a \mspace{9mu} b"#, #"a \hfill b"#] {
            XCTAssertGreaterThan(try display(latex).width, 0, "폭이 0: \(latex)")
        }
        // 간격이 실제로 자리를 차지한다.
        XCTAssertGreaterThan(try display(#"a \hspace{1cm} b"#).width,
                             try display("ab").width, "간격이 무시됐다")
        // 클수록 넓어진다.
        XCTAssertGreaterThan(try display(#"a \mkern 36mu b"#).width,
                             try display(#"a \mkern 9mu b"#).width)
    }

    func testSurfaceIntegrals() throws {
        for command in ["oiint", "oiiint", "iiiint", "smallint"] {
            XCTAssertGreaterThan(try display("\\\(command) f").width, 0, "\\\(command) 실패")
        }
    }

    // MARK: - 사용자 매크로

    func testNewcommandWithoutArguments() throws {
        let list = try build(#"\newcommand{\R}{\mathbb{R}} x \in \R"#)
        XCTAssertGreaterThan(list.atoms.count, 0)
        // 정의만 있는 경우 아무것도 안 그린다.
        XCTAssertEqual(try display(#"\newcommand{\R}{\mathbb{R}}"#).width, 0, accuracy: 0.01)
    }

    func testNewcommandWithArguments() throws {
        let expanded = try display(#"\newcommand{\f}[1]{f(#1)} \f{x}"#)
        let manual = try display(#"f(x)"#)
        XCTAssertEqual(expanded.width, manual.width, accuracy: 0.5, "인자 치환이 어긋났다")
    }

    func testTwoArguments() throws {
        let expanded = try display(#"\newcommand{\pair}[2]{(#1,#2)} \pair{a}{b}"#)
        let manual = try display(#"(a,b)"#)
        XCTAssertEqual(expanded.width, manual.width, accuracy: 0.5)
    }

    func testDefAndRenewcommand() throws {
        XCTAssertGreaterThan(try display(#"\def\z{z} \z + 1"#).width, 0)
        XCTAssertGreaterThan(try display(#"\renewcommand{\q}{q} \q"#).width, 0)
    }

    func testDeclareMathOperator() throws {
        let d = try display(#"\DeclareMathOperator{\myop}{myop} \myop x"#)
        XCTAssertGreaterThan(d.width, 0)
    }

    /// 자기를 참조하는 정의가 무한히 돌면 안 된다 — 신뢰할 수 없는 입력을 렌더하므로
    /// 이 방어가 없으면 앱이 멈춘다.
    func testSelfReferentialMacroTerminates() {
        var error: NSError?
        _ = MTMathListBuilder.build(fromString: #"\def\x{\x} \x"#, error: &error)
        XCTAssertNotNil(error, "자기 참조 매크로가 오류 없이 끝났다")
        XCTAssertEqual(error?.code, MTParseErrors.nestingTooDeep.rawValue)
    }

    func testMutuallyRecursiveMacrosTerminate() {
        var error: NSError?
        _ = MTMathListBuilder.build(fromString: #"\def\a{\b} \def\b{\a} \a"#, error: &error)
        XCTAssertNotNil(error, "상호 재귀 매크로가 오류 없이 끝났다")
    }

    /// 매크로 안에서 CJK 도 살아야 한다.
    func testMacroWithCJK() throws {
        let expanded = try display(#"\newcommand{\v}{\text{속도}} \v = 5"#)
        let manual = try display(#"\text{속도} = 5"#)
        XCTAssertEqual(expanded.width, manual.width, accuracy: 0.5)
    }

    /// 정의가 없는 명령은 여전히 오류여야 한다 — 매크로 조회가 오류를 삼키면 안 된다.
    func testUnknownCommandStillErrors() {
        var error: NSError?
        _ = MTMathListBuilder.build(fromString: #"\nosuchcommand"#, error: &error)
        XCTAssertNotNil(error)
    }
}
