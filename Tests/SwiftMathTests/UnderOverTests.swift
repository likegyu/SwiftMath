import XCTest
@testable import SwiftMath

/// `\overset`·`\underset`·`\stackrel`·`\substack` 이 **장식을 그리는지** 확인한다.
///
/// 이전에는 이런 매크로가 앱 단에서 토큰을 지우는 식으로 강등돼, `\overset{def}{=}` 가
/// 그냥 `=` 로 나왔다. 파싱이 되는 것만으로는 부족하고, 위·아래 내용이 실제로 조판
/// 결과에 들어가 높이를 늘려야 한다.
final class UnderOverTests: XCTestCase {

    private func build(_ latex: String, file: StaticString = #filePath, line: UInt = #line) throws -> MTMathList {
        var error: NSError?
        let list = MTMathListBuilder.build(fromString: latex, error: &error)
        XCTAssertNil(error, "파싱 오류 (\(latex)): \(error?.localizedDescription ?? "")",
                     file: file, line: line)
        return try XCTUnwrap(list, file: file, line: line)
    }

    private func display(_ latex: String, size: CGFloat = 20) throws -> MTMathListDisplay {
        let font = try XCTUnwrap(MTFontManager.fontManager.latinModernFont(withSize: size))
        return try XCTUnwrap(MTTypesetter.createLineForMathList(try build(latex), font: font, style: .display))
    }

    // MARK: - 파싱

    func testOversetParsesToUnderOver() throws {
        let list = try build(#"\overset{a}{b}"#)
        let atom = try XCTUnwrap(list.atoms.first as? MTUnderOver)
        XCTAssertEqual(atom.type, .underOver)
        XCTAssertEqual(atom.over?.atoms.first?.nucleus, "a")
        XCTAssertEqual(atom.innerList?.atoms.first?.nucleus, "b")
        XCTAssertNil(atom.under)
    }

    func testUndersetPutsDecorationBelow() throws {
        let list = try build(#"\underset{a}{b}"#)
        let atom = try XCTUnwrap(list.atoms.first as? MTUnderOver)
        XCTAssertEqual(atom.under?.atoms.first?.nucleus, "a")
        XCTAssertEqual(atom.innerList?.atoms.first?.nucleus, "b")
        XCTAssertNil(atom.over)
    }

    /// \stackrel 은 관계연산자 자리에 쓰인다 — 간격이 관계연산자와 같아야 한다.
    func testStackrelIsRelation() throws {
        let list = try build(#"\stackrel{def}{=}"#)
        let atom = try XCTUnwrap(list.atoms.first as? MTUnderOver)
        XCTAssertEqual(atom.type, .relation)
    }

    func testSubstackBuildsCenteredColumn() throws {
        let list = try build(#"\substack{a \\ b \\ c}"#)
        let table = try XCTUnwrap(list.atoms.first as? MTMathTable)
        XCTAssertEqual(table.numRows, 3)
        XCTAssertEqual(table.numColumns, 1)
        XCTAssertEqual(table.get(alignmentForColumn: 0), .center)
    }

    // MARK: - 조판 (장식이 실제로 그려지는가)

    /// 위 장식이 붙으면 **더 높아져야** 한다. 안 높아지면 장식이 버려진 것이다.
    func testOversetAddsHeight() throws {
        let bare = try display("b")
        let decorated = try display(#"\overset{a}{b}"#)
        XCTAssertGreaterThan(decorated.ascent, bare.ascent,
                             "\\overset 이 위쪽 높이를 늘리지 않았다 — 장식이 사라졌다")
        XCTAssertEqual(decorated.descent, bare.descent, accuracy: 0.5,
                       "위 장식인데 아래로 자랐다")
    }

    func testUndersetAddsDepth() throws {
        let bare = try display("b")
        let decorated = try display(#"\underset{a}{b}"#)
        XCTAssertGreaterThan(decorated.descent, bare.descent,
                             "\\underset 이 아래쪽 깊이를 늘리지 않았다")
        XCTAssertEqual(decorated.ascent, bare.ascent, accuracy: 0.5,
                       "아래 장식인데 위로 자랐다")
    }

    /// 위·아래를 같이 주면 양쪽으로 자란다.
    func testOversetAndUndersetCombine() throws {
        let both = try display(#"\underset{c}{\overset{a}{b}}"#)
        let bare = try display("b")
        XCTAssertGreaterThan(both.ascent, bare.ascent)
        XCTAssertGreaterThan(both.descent, bare.descent)
    }

    /// 장식이 본체보다 넓으면 전체 폭이 장식을 따라간다.
    func testWideDecorationWidensResult() throws {
        let narrow = try display(#"\overset{a}{b}"#)
        let wide = try display(#"\overset{abcdef}{b}"#)
        XCTAssertGreaterThan(wide.width, narrow.width,
                             "넓은 장식이 폭에 반영되지 않았다")
    }

    /// 장식은 script 크기로 줄어든다 — 본체와 같은 크기로 나오면 안 된다.
    func testDecorationIsScriptSized() throws {
        // 같은 내용을 본체로 쓴 것과 장식으로 쓴 것의 폭을 비교한다.
        let asBase = try display(#"\overset{x}{abcdef}"#)
        let asDecoration = try display(#"\overset{abcdef}{x}"#)
        XCTAssertLessThan(asDecoration.width, asBase.width,
                          "장식이 본체와 같은 크기로 그려졌다 — script 축소가 안 됐다")
    }

    func testSubstackTypesets() throws {
        let stacked = try display(#"\sum_{\substack{i<n \\ j<m}} a_{ij}"#)
        let plain = try display(#"\sum_{i<n} a_{ij}"#)
        XCTAssertGreaterThan(stacked.descent, plain.descent,
                             "\\substack 이 여러 줄로 쌓이지 않았다")
    }

    // MARK: - CJK

    func testCJKDecoration() throws {
        for latex in [#"\overset{정의}{=}"#, #"\underset{질량}{m}"#,
                      #"\stackrel{\text{정의}}{\equiv}"#, #"\substack{속도 \\ 가속도}"#] {
            let d = try display(latex)
            XCTAssertGreaterThan(d.width, 0, "폭이 0: \(latex)")
            XCTAssertGreaterThan(d.ascent + d.descent, 0, "높이가 0: \(latex)")
        }
    }

    /// 한글 장식도 높이를 늘려야 한다 — CJK가 폴백 경로를 타도 조판 결과에 들어가는지.
    func testCJKDecorationAddsHeight() throws {
        let bare = try display("m")
        let decorated = try display(#"\overset{질량}{m}"#)
        XCTAssertGreaterThan(decorated.ascent, bare.ascent)
    }

    // MARK: - 간격

    /// 장식을 얹어도 간격이 **원래 수식과 같아야** 한다.
    ///
    /// 본체를 조판할 때 이미 그 성격의 여백이 폭에 들어가므로, 감싸면서 한 번 더
    /// 더하면 안 된다. 예전에 그렇게 해서 5.56pt 씩 벌어진 적이 있다.
    func testDecorationDoesNotDoubleCountSpacing() throws {
        let decorated = try display(#"A\stackrel{f}{\rightarrow}B"#)
        let plain = try display(#"A\rightarrow B"#)
        XCTAssertEqual(decorated.width, plain.width, accuracy: 0.5,
                       "\\stackrel 이 간격을 두 번 먹였다")
    }

    /// \overset 은 보통 원자 간격 — 괜히 벌어지면 안 된다.
    func testOversetKeepsOrdinarySpacing() throws {
        let decorated = try display(#"A\overset{f}{x}B"#)
        let plain = try display("AxB")
        XCTAssertEqual(decorated.width, plain.width, accuracy: 0.5,
                       "\\overset 이 없던 간격을 만들었다")
    }

    /// 본체가 관계연산자·이항연산자면 그 성격을 물려받는다(amsmath \binrel@).
    func testInheritsBaseSpacingClass() throws {
        let relation = try build(#"\overset{?}{=}"#)
        XCTAssertEqual((relation.atoms.first as? MTUnderOver)?.type, .relation,
                       "`=` 위에 장식을 얹었더니 관계연산자가 아니게 됐다")

        let binary = try build(#"\overset{a}{+}"#)
        XCTAssertEqual((binary.atoms.first as? MTUnderOver)?.type, .binaryOperator)

        let ordinary = try build(#"\overset{a}{x}"#)
        XCTAssertEqual((ordinary.atoms.first as? MTUnderOver)?.type, .underOver)

        // 본체가 여러 원자면 물려받을 성격이 없다 — 보통 원자로 둔다.
        let multi = try build(#"\overset{a}{x+y}"#)
        XCTAssertEqual((multi.atoms.first as? MTUnderOver)?.type, .underOver)
    }

    /// 물려받은 성격이 실제 간격으로 이어지는가.
    func testInheritedRelationWidensLayout() throws {
        let decorated = try display(#"x\overset{?}{=}y"#)
        let plain = try display("x=y")
        XCTAssertEqual(decorated.width, plain.width, accuracy: 1.0,
                       "`=` 의 관계연산자 간격이 장식 때문에 사라졌다")
    }

    // MARK: - LaTeX 되돌리기

    /// 파싱한 걸 다시 문자열로 뽑으면 장식이 남아 있어야 한다.
    func testRoundTripsToLatex() throws {
        let cases = [
            #"\overset{a}{b}"#,
            #"\underset{a}{b}"#,
            #"\overset{정의}{=}"#,
        ]
        for latex in cases {
            let list = try build(latex)
            let out = MTMathListBuilder.mathListToString(list)
            XCTAssertEqual(out.replacingOccurrences(of: " ", with: ""),
                           latex.replacingOccurrences(of: " ", with: ""),
                           "되돌린 문자열이 다르다")
        }
    }

    /// 위·아래를 동시에 가진 경우도 다시 읽을 수 있는 형태로 나와야 한다.
    func testRoundTripBothSides() throws {
        let list = try build(#"\underset{c}{\overset{a}{b}}"#)
        let out = MTMathListBuilder.mathListToString(list)
        let reparsed = try build(out)
        let outer = try XCTUnwrap(reparsed.atoms.first as? MTUnderOver)
        XCTAssertNotNil(outer.under, "되돌린 문자열에서 아래 장식이 사라졌다")
    }

    // MARK: - 실패 처리

    /// 인자가 모자라면 크래시가 아니라 오류로 끝나야 한다.
    func testMalformedDoesNotCrash() {
        for latex in [#"\overset"#, #"\overset{a}"#, #"\substack"#, #"\substack a"#,
                      #"\underset{"#, #"\stackrel{a}{"#] {
            var error: NSError?
            _ = MTMathListBuilder.build(fromString: latex, error: &error)
            // 파싱이 성공하든 실패하든 크래시하지만 않으면 된다. 성공했다면 조판도 되는지 본다.
            if error == nil, let list = MTMathListBuilder.build(fromString: latex, error: &error),
               let font = MTFontManager.fontManager.latinModernFont(withSize: 20) {
                _ = MTTypesetter.createLineForMathList(list, font: font, style: .display)
            }
        }
    }
}
