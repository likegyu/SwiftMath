import XCTest
@testable import SwiftMath

/// `\boxed` 과 `\cancel` 계열이 실제로 선을 그리는지 확인한다.
final class DecoratedTests: XCTestCase {

    private func build(_ latex: String, file: StaticString = #filePath, line: UInt = #line) throws -> MTMathList {
        var error: NSError?
        let list = MTMathListBuilder.build(fromString: latex, error: &error)
        XCTAssertNil(error, "파싱 오류 (\(latex)): \(error?.localizedDescription ?? "")", file: file, line: line)
        return try XCTUnwrap(list, file: file, line: line)
    }

    private func display(_ latex: String, size: CGFloat = 20) throws -> MTMathListDisplay {
        let font = try XCTUnwrap(MTFontManager.fontManager.latinModernFont(withSize: size))
        return try XCTUnwrap(MTTypesetter.createLineForMathList(try build(latex), font: font, style: .display))
    }

    func testParsesToDecorated() throws {
        let expected: [(String, MTDecorated.Kind)] = [
            ("boxed", .boxed), ("fbox", .boxed), ("framebox", .boxed),
            ("cancel", .cancel), ("bcancel", .backCancel), ("xcancel", .crossCancel),
        ]
        for (command, kind) in expected {
            let list = try build("\\\(command){x}")
            let atom = try XCTUnwrap(list.atoms.first as? MTDecorated, "\\\(command) 이 원자가 안 됐다")
            XCTAssertEqual(atom.kind, kind)
            XCTAssertEqual(atom.innerList?.atoms.first?.nucleus, "x")
        }
    }

    /// \boxed 는 테두리 여백만큼 커진다.
    func testBoxedGrowsByPadding() throws {
        let bare = try display("x+y")
        let boxed = try display(#"\boxed{x+y}"#)
        XCTAssertGreaterThan(boxed.width, bare.width, "테두리 여백이 폭에 반영되지 않았다")
        XCTAssertGreaterThan(boxed.ascent, bare.ascent)
        XCTAssertGreaterThan(boxed.descent, bare.descent)
    }

    /// \cancel 은 자리를 더 먹지 않는다 — 취소선은 내용 위에 겹쳐 그린다.
    func testCancelKeepsSize() throws {
        let bare = try display("x+y")
        for command in ["cancel", "bcancel", "xcancel"] {
            let cancelled = try display("\\\(command){x+y}")
            XCTAssertEqual(cancelled.width, bare.width, accuracy: 0.01,
                           "\\\(command) 이 폭을 바꿨다")
            XCTAssertEqual(cancelled.ascent, bare.ascent, accuracy: 0.01)
            XCTAssertEqual(cancelled.descent, bare.descent, accuracy: 0.01)
        }
    }

    /// 중첩·조합에서도 조판된다.
    func testNestingAndCJK() throws {
        let cases = [
            #"\boxed{\frac{a}{b}}"#,
            #"\boxed{정답: x = 5}"#,
            #"\frac{\cancel{x}}{\cancel{x}} = 1"#,
            #"\boxed{\cancel{a} + b}"#,
            #"\cancel{\text{속도}}"#,
            #"\boxed{E = mc^2 \quad \text{에너지}}"#,
        ]
        for latex in cases {
            let d = try display(latex)
            XCTAssertGreaterThan(d.width, 0, "폭이 0: \(latex)")
        }
    }

    func testRoundTripsToLatex() throws {
        for latex in [#"\boxed{x}"#, #"\cancel{x}"#, #"\bcancel{x}"#, #"\xcancel{x}"#] {
            let out = MTMathListBuilder.mathListToString(try build(latex))
            XCTAssertEqual(out.replacingOccurrences(of: " ", with: ""), latex,
                           "되돌린 문자열이 다르다")
        }
    }

    /// 인자가 없거나 깨져도 크래시하지 않는다.
    func testMalformedDoesNotCrash() {
        for latex in [#"\boxed"#, #"\cancel{"#, #"\boxed{}"#, #"\xcancel"#] {
            var error: NSError?
            if let list = MTMathListBuilder.build(fromString: latex, error: &error),
               let font = MTFontManager.fontManager.latinModernFont(withSize: 20) {
                _ = MTTypesetter.createLineForMathList(list, font: font, style: .display)
            }
        }
    }
}
