import XCTest
@testable import SwiftMath

/// Tier 2 — `array`·`gathered`·`subarray` 환경, 늘어나는 화살표, 아래쪽 늘어나는 악센트.
final class ArrayAndArrowTests: XCTestCase {

    private func build(_ latex: String, file: StaticString = #filePath, line: UInt = #line) throws -> MTMathList {
        var error: NSError?
        let list = MTMathListBuilder.build(fromString: latex, error: &error)
        XCTAssertNil(error, "파싱 오류 (\(latex)): \(error?.localizedDescription ?? "")", file: file, line: line)
        return try XCTUnwrap(list, file: file, line: line)
    }

    private func display(_ latex: String, size: CGFloat = 20,
                         file: StaticString = #filePath, line: UInt = #line) throws -> MTMathListDisplay {
        let font = try XCTUnwrap(MTFontManager.fontManager.latinModernFont(withSize: size), file: file, line: line)
        return try XCTUnwrap(MTTypesetter.createLineForMathList(try build(latex, file: file, line: line),
                                                               font: font, style: .display),
                             "조판 실패: \(latex)", file: file, line: line)
    }

    // MARK: - array

    func testArrayRespectsColumnSpec() throws {
        let table = try XCTUnwrap(try build(#"\begin{array}{lcr} a & b & c \end{array}"#)
            .atoms.first as? MTMathTable)
        XCTAssertEqual(table.numColumns, 3)
        XCTAssertEqual(table.get(alignmentForColumn: 0), .left)
        XCTAssertEqual(table.get(alignmentForColumn: 1), .center)
        XCTAssertEqual(table.get(alignmentForColumn: 2), .right)
    }

    func testArrayRowsAndColumns() throws {
        let table = try XCTUnwrap(try build("\\begin{array}{cc} a & b \\\\ c & d \\end{array}")
            .atoms.first as? MTMathTable)
        XCTAssertEqual(table.numRows, 2)
        XCTAssertEqual(table.numColumns, 2)
    }

    /// 세로줄(`|`)은 그릴 수 없으니 **무시하되 열은 안 늘어나야** 한다.
    func testVerticalRulesAreIgnoredNotCounted() throws {
        let table = try XCTUnwrap(try build(#"\begin{array}{c|c} a & b \end{array}"#)
            .atoms.first as? MTMathTable)
        XCTAssertEqual(table.numColumns, 2, "세로줄이 열로 세어졌다")
    }

    /// 열 지정이 없으면 오류다 — LaTeX 에서도 필수 인자다.
    func testArrayWithoutColumnSpecErrors() {
        var error: NSError?
        _ = MTMathListBuilder.build(fromString: #"\begin{array} a \end{array}"#, error: &error)
        XCTAssertNotNil(error, "열 지정이 없는데 통과했다")
    }

    /// 지정보다 열이 많으면 남는 열은 가운데로 — 내용을 버리지 않는다.
    func testExtraColumnsFallBackToCenter() throws {
        let table = try XCTUnwrap(try build(#"\begin{array}{l} a & b \end{array}"#)
            .atoms.first as? MTMathTable)
        XCTAssertEqual(table.get(alignmentForColumn: 0), .left)
        XCTAssertEqual(table.get(alignmentForColumn: 1), .center)
    }

    func testArrayInsideDelimiters() throws {
        let d = try display("\\left[\\begin{array}{cc} 가 & 나 \\\\ 다 & 라 \\end{array}\\right]")
        XCTAssertGreaterThan(d.width, 0)
    }

    // MARK: - gathered · subarray

    func testGathered() throws {
        let table = try XCTUnwrap(try build("\\begin{gathered} a \\\\ b \\end{gathered}")
            .atoms.first as? MTMathTable)
        XCTAssertEqual(table.numRows, 2)
        XCTAssertEqual(table.numColumns, 1)
        XCTAssertEqual(table.get(alignmentForColumn: 0), .center)
    }

    func testGatheredRejectsMultipleColumns() {
        var error: NSError?
        _ = MTMathListBuilder.build(fromString: #"\begin{gathered} a & b \end{gathered}"#, error: &error)
        XCTAssertNotNil(error, "gathered 가 여러 열을 받았다")
    }

    /// subarray 는 열 간격이 없다 — array 와의 유일한 차이다.
    ///
    /// 크기 축소는 넣지 않았다. 이 렌더러는 `MTMathStyle(.script)` 를 폭에 반영하지 않고
    /// (`\scriptstyle`·`smallmatrix` 도 같다), 실사용인 `\sum_{\begin{subarray}…}` 는
    /// 첨자 경로가 script 폰트로 조판하므로 이미 작게 나온다.
    func testSubarrayHasNoColumnSpacing() throws {
        let spaced = try display("\\begin{array}{cc} a & b \\end{array}")
        let tight = try display("\\begin{subarray}{cc} a & b \\end{subarray}")
        XCTAssertLessThan(tight.width, spaced.width, "subarray 에 열 간격이 남아 있다")
    }

    func testSubarrayUnderSum() throws {
        let d = try display("\\sum_{\\begin{subarray}{c} i<n \\\\ j<m \\end{subarray}} a_{ij}")
        let plain = try display(#"\sum_{i<n} a_{ij}"#)
        XCTAssertGreaterThan(d.descent, plain.descent, "여러 줄로 안 쌓였다")
    }

    // MARK: - 늘어나는 화살표

    func testStretchyArrowParses() throws {
        let atom = try XCTUnwrap(try build(#"\xrightarrow{f}"#).atoms.first as? MTUnderOver)
        XCTAssertEqual(atom.stretchyArrow, .right)
        XCTAssertNotNil(atom.over)
        XCTAssertNil(atom.under)
        XCTAssertEqual(atom.type, .relation, "화살표가 관계연산자가 아니다")
    }

    func testStretchyArrowBelowLabel() throws {
        let atom = try XCTUnwrap(try build(#"\xrightarrow[아래]{위}"#).atoms.first as? MTUnderOver)
        XCTAssertNotNil(atom.over, "위 라벨이 없다")
        XCTAssertNotNil(atom.under, "아래 라벨이 없다")
    }

    /// **핵심**: 화살표가 라벨 폭을 따라 늘어난다.
    func testArrowStretchesToLabel() throws {
        let short = try display(#"\xrightarrow{f}"#)
        let long = try display(#"\xrightarrow{\text{촉매 존재하에}}"#)
        XCTAssertGreaterThan(long.width, short.width * 2,
                             "라벨이 길어졌는데 화살표가 안 늘었다")
    }

    /// 라벨이 없어도 화살표 꼴은 유지한다.
    func testArrowHasMinimumLength() throws {
        let d = try display(#"\xrightarrow{}"#)
        XCTAssertGreaterThan(d.width, 20, "화살표가 너무 짧다")
    }

    func testArrowDirections() throws {
        for (command, expected) in [("xrightarrow", MTStretchyArrowDirection.right),
                                    ("xleftarrow", .left),
                                    ("xleftrightarrow", .both)] {
            let atom = try XCTUnwrap(try build("\\\(command){f}").atoms.first as? MTUnderOver)
            XCTAssertEqual(atom.stretchyArrow, expected, "\\\(command) 방향이 틀렸다")
        }
    }

    /// 라벨을 두 번 조판하면 글자가 겹친다 — `\xrightarrow{\text{촉매}}` 가 "촉매매" 였다.
    ///
    /// 폭을 재려고 한 번, 그리려고 또 한 번 조판했더니 전처리의 원자 융합(prevNode.fuse)이
    /// 원본 리스트를 두 번 건드렸다. 단정으로는 안 잡히고 렌더 시트를 보고 발견했다.
    func testLabelIsNotDuplicated() throws {
        var error: NSError?
        let list = try XCTUnwrap(MTMathListBuilder.build(
            fromString: #"\xrightarrow{\text{촉매}}"#, error: &error))
        let font = try XCTUnwrap(MTFontManager.fontManager.latinModernFont(withSize: 20))
        _ = MTTypesetter.createLineForMathList(list, font: font, style: .display)

        // 조판을 마친 뒤 원본 리스트의 글자가 그대로여야 한다.
        let atom = try XCTUnwrap(list.atoms.first as? MTUnderOver)
        let text = atom.over?.atoms.map(\.nucleus).joined() ?? ""
        XCTAssertEqual(text, "촉매", "라벨이 늘어났다 — 조판이 원본을 건드렸다")
    }

    /// 같은 리스트를 두 번 조판해도 결과가 같아야 한다(조판은 부작용이 없어야 한다).
    func testTypesettingIsIdempotent() throws {
        for latex in [#"\xrightarrow{\text{촉매}}"#, #"\overbrace{a+b}^{\text{합}}"#,
                      #"\overset{정의}{=}"#] {
            var error: NSError?
            let list = try XCTUnwrap(MTMathListBuilder.build(fromString: latex, error: &error))
            let font = try XCTUnwrap(MTFontManager.fontManager.latinModernFont(withSize: 20))
            let first = try XCTUnwrap(MTTypesetter.createLineForMathList(list, font: font, style: .display))
            let second = try XCTUnwrap(MTTypesetter.createLineForMathList(list, font: font, style: .display))
            XCTAssertEqual(first.width, second.width, accuracy: 0.01,
                           "두 번째 조판에서 폭이 달라졌다: \(latex)")
        }
    }

    func testChemistryFormula() throws {
        let d = try display(#"\text{A} \xrightarrow[\Delta]{\text{촉매}} \text{B}"#)
        XCTAssertGreaterThan(d.width, 0)
    }

    // MARK: - 아래쪽 늘어나는 악센트

    func testUnderAccents() throws {
        for command in ["underrightarrow", "underleftarrow", "underleftrightarrow", "underparen"] {
            let atom = try XCTUnwrap(try build("\\\(command){AB}").atoms.first as? MTUnderOver,
                                     "\\\(command) 가 원자가 안 됐다")
            XCTAssertNotNil(atom.stretchyUnder, "\\\(command) 가 아래에 안 붙었다")
            XCTAssertNil(atom.stretchyOver)
        }
    }

    func testOverParen() throws {
        let atom = try XCTUnwrap(try build(#"\overparen{AB}"#).atoms.first as? MTUnderOver)
        XCTAssertNotNil(atom.stretchyOver, "\\overparen 이 위에 안 붙었다")
        XCTAssertNil(atom.stretchyUnder)
    }

    func testUnderAccentAddsDepth() throws {
        let bare = try display("AB")
        let accented = try display(#"\underrightarrow{AB}"#)
        XCTAssertGreaterThan(accented.descent, bare.descent)
    }

    // MARK: - 조합 · 실패 처리

    func testCombinationsAndCJK() throws {
        for latex in ["\\begin{array}{cc} 속도 & 가속도 \\\\ 질량 & 부피 \\end{array}",
                      #"\text{반응물} \xrightarrow{\text{효소}} \text{생성물}"#,
                      #"\boxed{\begin{array}{c} a \end{array}}"#,
                      #"\underrightarrow{속도}"#] {
            let d = try display(latex)
            XCTAssertGreaterThan(d.width, 0, "폭이 0: \(latex)")
        }
    }

    func testMalformedDoesNotCrash() {
        for latex in [#"\begin{array}{"#, #"\begin{array}{cc}"#, #"\xrightarrow"#,
                      #"\xrightarrow["#, #"\underrightarrow"#, #"\begin{gathered}"#] {
            var error: NSError?
            if let list = MTMathListBuilder.build(fromString: latex, error: &error),
               let font = MTFontManager.fontManager.latinModernFont(withSize: 20) {
                _ = MTTypesetter.createLineForMathList(list, font: font, style: .display)
            }
        }
    }
}
