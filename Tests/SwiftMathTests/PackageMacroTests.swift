import XCTest
@testable import SwiftMath

/// 강의 노트에 실제로 나오는 패키지 매크로 — amsmath 디스플레이 환경, physics, 관례 연산자.
final class PackageMacroTests: XCTestCase {

    private func display(_ latex: String, file: StaticString = #filePath, line: UInt = #line) throws -> MTMathListDisplay {
        var error: NSError?
        let list = MTMathListBuilder.build(fromString: latex, error: &error)
        XCTAssertNil(error, "파싱 오류 (\(latex)): \(error?.localizedDescription ?? "")", file: file, line: line)
        let font = try XCTUnwrap(MTFontManager.fontManager.latinModernFont(withSize: 20), file: file, line: line)
        return try XCTUnwrap(MTTypesetter.createLineForMathList(try XCTUnwrap(list, file: file, line: line),
                                                               font: font, style: .display),
                             "조판 실패: \(latex)", file: file, line: line)
    }

    /// **가장 중요한 회귀 방지** — `align` 은 LaTeX 에서 가장 흔한 디스플레이 환경인데
    /// `aligned` 만 되고 `align` 은 통째로 실패했다.
    func testDisplayEnvironments() throws {
        let environments = ["align", "align*", "equation", "equation*", "multline", "multline*",
                            "gather", "gather*", "aligned", "gathered", "flalign"]
        for env in environments {
            let body = env.hasPrefix("align") || env.hasPrefix("flalign")
                ? "a &= b \\\\ c &= d" : "a \\\\ b"
            let d = try display("\\begin{\(env)} \(body) \\end{\(env)}")
            XCTAssertGreaterThan(d.width, 0, "\(env) 폭이 0")
        }
    }

    /// alignat 은 열 쌍 개수를 인자로 받는다 — 읽고 버려야 한다.
    func testAlignatConsumesItsArgument() throws {
        let d = try display("\\begin{alignat}{2} a &= b & c &= d \\end{alignat}")
        XCTAssertGreaterThan(d.width, 0)
    }

    func testDcases() throws {
        let d = try display("\\begin{dcases} 1 & x>0 \\\\ 0 & x\\le 0 \\end{dcases}")
        XCTAssertGreaterThan(d.width, 0)
    }

    // MARK: - physics 패키지

    func testDerivatives() throws {
        for latex in [#"\dv{f}{x}"#, #"\dv[2]{f}{x}"#, #"\pdv{f}{x}"#, #"\pdv[2]{u}{t}"#] {
            let d = try display(latex)
            XCTAssertGreaterThan(d.width, 0, "폭이 0: \(latex)")
        }
        // \pdv 는 ∂ 를 쓴다 — d 보다 넓다.
        XCTAssertGreaterThan(try display(#"\pdv{f}{x}"#).width,
                             try display(#"\dv{f}{x}"#).width,
                             "\\pdv 가 ∂ 를 쓰지 않는다")
    }

    func testVectorOperators() throws {
        for latex in [#"\grad V"#, #"\divergence \vec{E}"#, #"\curl \vec{B}"#, #"\laplacian \phi"#] {
            XCTAssertGreaterThan(try display(latex).width, 0, "폭이 0: \(latex)")
        }
    }

    func testPairedDelimiters() throws {
        for latex in [#"\abs{x}"#, #"\norm{v}"#, #"\ceil{x}"#, #"\floor{x}"#, #"\set{x \in A}"#] {
            XCTAssertGreaterThan(try display(latex).width, 0, "폭이 0: \(latex)")
        }
        // 감싸는 구분자가 실제로 붙는다 — 알맹이보다 넓어야 한다.
        XCTAssertGreaterThan(try display(#"\abs{x}"#).width, try display("x").width)
    }

    func testQuantumNotation() throws {
        for latex in [#"\bra{\psi}"#, #"\ket{\phi}"#, #"\braket{\psi}{\phi}"#,
                      #"\ev{H}"#, #"\comm{A}{B}"#, #"\acomm{A}{B}"#] {
            XCTAssertGreaterThan(try display(latex).width, 0, "폭이 0: \(latex)")
        }
    }

    /// `\braket` 이 원문 폴백으로 조용히 떨어지지 않는지 — 안쪽에 `\middle` 을 쓰기 때문.
    func testBraketDoesNotFallBackToText() throws {
        var error: NSError?
        let list = try XCTUnwrap(MTMathListBuilder.build(fromString: #"\braket{\psi}{\phi}"#, error: &error))
        XCTAssertNil(error)
        // 제대로 파싱되면 \left…\right 가 만든 MTInner 하나다. 폴백이면 평범한 텍스트 원자다.
        let inner = list.atoms.first as? MTInner
        XCTAssertNotNil(inner, "통짜 텍스트로 떨어졌다 — \\middle 이 안 먹었다")
        XCTAssertNotNil(inner?.leftBoundary, "여는 구분자가 없다")
        XCTAssertNotNil(inner?.rightBoundary, "닫는 구분자가 없다")
    }

    // MARK: - 관례 연산자

    func testConventionalOperators() throws {
        for command in ["tr", "rank", "diag", "sgn", "lcm", "Var", "Cov", "Res",
                        "Span", "im", "id", "Aut", "Hom", "End", "adj", "erf", "sinc"] {
            let d = try display("\\\(command) A")
            XCTAssertGreaterThan(d.width, 0, "\\\(command) 폭이 0")
        }
    }

    // MARK: - 무시해야 하는 명령

    /// `\notag` 는 번호를 안 붙이라는 지시다. 앱엔 번호가 없으니 **조용히 무시**해야지
    /// 오류를 내면 수식 하나가 통째로 날아간다.
    func testNotagIsIgnored() throws {
        let withNotag = try display(#"a = b \notag"#)
        let plain = try display("a = b")
        XCTAssertEqual(withNotag.width, plain.width, accuracy: 0.5)
    }

    func testMiddleDelimiter() throws {
        let d = try display(#"\left\{ x \middle| x>0 \right\}"#)
        XCTAssertGreaterThan(d.width, 0)
    }

    // MARK: - CJK 혼합

    func testWithCJK() throws {
        for latex in [#"\dv{\text{위치}}{\text{시간}} = \text{속도}"#,
                      "\\begin{align} 좌변 &= 우변 \\\\ 가 &= 나 \\end{align}",
                      #"\abs{\text{오차}} < \epsilon"#,
                      #"\text{계수} = \tr(A)"#] {
            XCTAssertGreaterThan(try display(latex).width, 0, "폭이 0: \(latex)")
        }
    }
}
