import XCTest
@testable import SwiftMath

/// 색 명령이 **감싼 내용을 지우지 않는지** 확인한다.
///
/// 원래 증상: 색 원자가 `tokenizeTextAtom` 으로 흘러가는데 그 함수는 `atom.nucleus` 가
/// 비면 nil 을 낸다. 색 원자의 내용은 innerList 에 있어 nucleus 는 항상 비어 있으므로,
/// 감싼 내용이 통째로 사라졌다. 색 원자만 있는 수식은 조판 자체가 실패했다.
/// 소리 없는 내용 유실이라 눈에 띄지도 않았다.
final class ColorTests: XCTestCase {

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

    /// 색 명령만 있는 수식도 조판된다(예전엔 nil 이었다).
    func testColorOnlyFormulaTypesets() throws {
        for latex in [#"\textcolor{red}{xyz}"#, #"\color{blue}{xyz}"#, #"\colorbox{yellow}{xyz}"#] {
            let d = try display(latex)
            XCTAssertGreaterThan(d.width, 0, "폭이 0: \(latex)")
        }
    }

    /// **핵심**: 색으로 감싼 내용이 감싸지 않은 것과 같은 폭이어야 한다.
    /// 내용이 사라지면 폭이 줄어든다.
    func testContentIsNotDropped() throws {
        let bare = try display("xyz")
        for latex in [#"\textcolor{red}{xyz}"#, #"\color{blue}{xyz}"#, #"\colorbox{yellow}{xyz}"#] {
            let colored = try display(latex)
            XCTAssertEqual(colored.width, bare.width, accuracy: 0.01,
                           "\(latex) 의 내용이 사라졌다 (색 \(colored.width) vs 무색 \(bare.width))")
        }
    }

    /// 다른 원자와 섞였을 때도 내용이 남아야 한다.
    func testContentSurvivesInMixedFormula() throws {
        let bare = try display("x + y")
        let colored = try display(#"x + \textcolor{red}{y}"#)
        XCTAssertEqual(colored.width, bare.width, accuracy: 0.5,
                       "섞인 수식에서 색 부분이 사라졌다")
    }

    /// 색이 실제로 걸리는가.
    func testColorIsApplied() throws {
        let d = try display(#"\textcolor{red}{x}"#)
        let sub = try XCTUnwrap(d.subDisplays.first)
        XCTAssertEqual(sub.localTextColor, MTColor(red: 1, green: 0, blue: 0, alpha: 1),
                       "빨강이 안 걸렸다")
    }

    /// 첨자가 붙은 내용에도 색이 걸려야 한다.
    ///
    /// 첨자 있는 원자는 그룹으로 묶여 `renderGroup` 경로로 빠지는데, 처음엔 그쪽에 색
    /// 적용을 안 걸어서 `\textcolor{red}{x^2}` 만 검게 나왔다. 단정으로는 안 잡히고
    /// 렌더 시트를 눈으로 보고서야 발견했다.
    func testColorAppliesToScriptedContent() throws {
        for latex in [#"\textcolor{red}{x^2}"#, #"\textcolor{red}{x_i}"#,
                      #"\textcolor{red}{x_i^2}"#] {
            let d = try display(latex)
            let colored = d.subDisplays.filter { $0.localTextColor != nil }
            XCTAssertFalse(colored.isEmpty, "첨자가 붙으니 색이 사라졌다: \(latex)")
        }
    }

    func testColorboxSetsBackground() throws {
        let d = try display(#"\colorbox{yellow}{x}"#)
        let sub = try XCTUnwrap(d.subDisplays.first)
        XCTAssertNotNil(sub.localBackgroundColor, "배경색이 안 걸렸다")
        XCTAssertNil(sub.localTextColor, "colorbox 가 글자색을 바꿨다")
    }

    /// 바깥에서 전체 색을 덮어써도 **개별 지정색은 살아남아야** 한다.
    /// MathImage 는 렌더 직전에 displayList.textColor 를 통째로 설정한다.
    func testLocalColorSurvivesGlobalOverride() throws {
        let d = try display(#"x + \textcolor{red}{y}"#)
        d.textColor = MTColor(red: 0, green: 0, blue: 0, alpha: 1)   // 전체를 검정으로
        let colored = d.subDisplays.first { $0.localTextColor != nil }
        XCTAssertEqual(colored?.localTextColor, MTColor(red: 1, green: 0, blue: 0, alpha: 1),
                       "전역 색 지정이 개별 색을 덮어썼다")
    }

    /// 모르는 색 이름이면 **색만 포기하고 내용은 남긴다**.
    func testUnknownColorNameKeepsContent() throws {
        let bare = try display("xyz")
        let weird = try display(#"\textcolor{chartreuse}{xyz}"#)
        XCTAssertEqual(weird.width, bare.width, accuracy: 0.01,
                       "모르는 색 이름 때문에 내용이 사라졌다")
        XCTAssertNil(weird.subDisplays.first?.localTextColor)
    }

    func testHexColor() throws {
        let d = try display(#"\textcolor{#00FF00}{x}"#)
        XCTAssertEqual(d.subDisplays.first?.localTextColor,
                       MTColor(red: 0, green: 1, blue: 0, alpha: 1))
    }

    func testColorNameTable() {
        XCTAssertNotNil(MTColor.fromLatexColorName("red"))
        XCTAssertNotNil(MTColor.fromLatexColorName("Blue"))       // 대소문자 무시
        XCTAssertNotNil(MTColor.fromLatexColorName(" gray "))     // 공백 허용
        XCTAssertNotNil(MTColor.fromLatexColorName("grey"))       // 영국식 철자
        XCTAssertNotNil(MTColor.fromLatexColorName("#ABCDEF"))
        XCTAssertNil(MTColor.fromLatexColorName("nosuchcolor"))
    }

    /// 색 안에 구조·CJK가 들어가도 유지된다.
    func testNestedAndCJK() throws {
        let cases = [
            (#"\textcolor{red}{\frac{a}{b}}"#, #"\frac{a}{b}"#),
            (#"\textcolor{blue}{\text{중요}}"#, #"\text{중요}"#),
            (#"\colorbox{yellow}{\boxed{정답}}"#, #"\boxed{정답}"#),
            (#"\textcolor{red}{\sqrt{속도^2}}"#, #"\sqrt{속도^2}"#),
        ]
        for (colored, plain) in cases {
            let a = try display(colored), b = try display(plain)
            XCTAssertEqual(a.width, b.width, accuracy: 0.01, "내용이 달라졌다: \(colored)")
        }
    }

    /// LaTeX 되돌리기가 색을 잃지 않는다.
    func testRoundTrip() throws {
        for latex in [#"\textcolor{red}{x}"#, #"\colorbox{yellow}{x}"#] {
            var error: NSError?
            let list = try XCTUnwrap(MTMathListBuilder.build(fromString: latex, error: &error))
            let out = MTMathListBuilder.mathListToString(list)
            XCTAssertTrue(out.contains("red") || out.contains("yellow"),
                          "되돌린 문자열에서 색이 사라졌다: \(out)")
        }
    }
}
