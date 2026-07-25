import XCTest
@testable import SwiftMath

/// 명시적 공백 명령의 폭과, 스캐너가 CJK를 삼키지 않는지.
final class SpacingAndCJKScannerTests: XCTestCase {

    private func width(_ latex: String, file: StaticString = #filePath, line: UInt = #line) -> CGFloat {
        var image = MTMathImage(latex: latex, fontSize: 20, textColor: MTColor.black)
        let (error, rendered) = image.asImage()
        XCTAssertNil(error, "render failed for \(latex): \(String(describing: error))", file: file, line: line)
        guard let rendered else {
            XCTFail("no image for \(latex)", file: file, line: line)
            return 0
        }
        return rendered.size.width
    }

    // MARK: - 공백 명령이 서로 다른 폭을 갖는다

    /// 이전에는 \, \: \; \quad \qquad \! 가 **전부 3mu 상수**로 뭉개져 같은 폭이었다.
    /// (\! 는 음수여야 하는데 양수가 되어 부호까지 뒤집혔다.)
    func testSpacingCommandsHaveDistinctWidths() {
        let base = width("ab")
        let thin = width(#"a\,b"#)      // 3mu
        let medium = width(#"a\:b"#)    // 4mu — 파싱 자체가 실패하던 명령
        let thick = width(#"a\;b"#)     // 5mu
        let quad = width(#"a\quad b"#)  // 18mu
        let qquad = width(#"a\qquad b"#) // 36mu
        let negative = width(#"a\!b"#)  // -3mu

        // 단조 증가해야 한다.
        XCTAssertLessThan(base, thin)
        XCTAssertLessThan(thin, medium)
        XCTAssertLessThan(medium, thick)
        XCTAssertLessThan(thick, quad)
        XCTAssertLessThan(quad, qquad)
        // 음수 공백은 기준보다 좁아야 한다.
        XCTAssertLessThan(negative, base,
                          "\\! 는 음수 공백이므로 'ab'보다 좁아야 한다 (현재 \(negative) vs \(base))")
        // \qquad 는 \, 대비 확연히 넓어야 한다(상수 뭉개짐 회귀 가드).
        XCTAssertGreaterThan(qquad - thin, 20, "\\qquad 와 \\, 의 차이가 거의 없다 — 상수 폭 회귀")
    }

    func testMediumSpaceParses() {
        var err: NSError? = nil
        XCTAssertNotNil(MTMathListBuilder.build(fromString: #"a\:b"#, error: &err),
                        "\\: 파싱 실패: \(err?.localizedDescription ?? "")")
    }

    // MARK: - 스캐너가 CJK를 삼키지 않는다

    /// 이전에는 skipSpaces()가 비-ASCII를 공백처럼 건너뛰어 **오류 없이 사라졌다**:
    /// "\left한(x\right)" → "\left( x\right)". 조용한 소멸 대신 명시적 실패여야 한다.
    func testDelimiterScannerDoesNotSwallowCJK() {
        var err: NSError? = nil
        let list = MTMathListBuilder.build(fromString: #"\left한(x\right)"#, error: &err)
        if let list {
            let out = MTMathListBuilder.mathListToString(list)
            XCTAssertTrue(out.contains("한"),
                          "파싱에 성공했다면 '한'이 보존돼야 한다 — 조용한 소멸 회귀: \(out)")
        } else {
            XCTAssertNotNil(err, "실패했다면 오류가 있어야 한다")
        }
    }

    func testColorArgumentScannerDoesNotSwallowCJK() {
        // "\color{빨강}{x}" 가 "{}" 로 붕괴하던 케이스 — 내용이 통째로 사라지면 안 된다.
        var err: NSError? = nil
        let list = MTMathListBuilder.build(fromString: #"\color{빨강}{x}"#, error: &err)
        if let list {
            let out = MTMathListBuilder.mathListToString(list)
            XCTAssertTrue(out.contains("x"), "x 가 사라졌다: \(out)")
        }
        // 실패해도 무방 — 앱이 원문 폴백으로 내용을 보존한다. 조용한 소멸만 아니면 된다.
    }

    // MARK: - 회귀 가드

    func testAsciiWhitespaceStillSkipped() {
        var err: NSError? = nil
        XCTAssertNotNil(MTMathListBuilder.build(fromString: #"\left ( x \right )"#, error: &err),
                        "ASCII 공백은 여전히 건너뛰어야 한다: \(err?.localizedDescription ?? "")")
    }

    func testAccentedLatinStillWorks() {
        // supportedAccentedCharacters 경로(é·ü 등)는 물리·화학 자료에 흔하다.
        for s in ["é", "ü", "ñ"] {
            var err: NSError? = nil
            XCTAssertNotNil(MTMathListBuilder.build(fromString: s, error: &err),
                            "\(s) 파싱 실패: \(err?.localizedDescription ?? "")")
        }
    }
}
