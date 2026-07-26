import XCTest
@testable import SwiftMath

/// 깊은 중첩이 스택 오버플로 대신 **평범한 파싱 오류**로 끝나는지 확인한다.
///
/// 왜 중요한가: 스택 오버플로는 Swift 에서 잡을 수 없다. `error` 로 돌아오지 않고
/// 프로세스가 그 자리에서 죽는다. LLM 이 만든 LaTeX 처럼 신뢰할 수 없는 입력을 렌더하는
/// 앱에서는 이게 곧 앱 강제종료다. 실측으로는 메인 스레드(1MB)에서 약 700중첩,
/// 백그라운드(512KB)에서 약 400중첩에 죽었다.
final class NestingDepthTests: XCTestCase {

    private func deepBraces(_ n: Int) -> String {
        String(repeating: "{", count: n) + "x" + String(repeating: "}", count: n)
    }

    /// 한계를 넘는 중첩은 크래시가 아니라 오류를 낸다.
    func testDeepNestingReportsErrorInsteadOfCrashing() {
        var error: NSError?
        let list = MTMathListBuilder.build(fromString: deepBraces(5000), error: &error)

        XCTAssertNil(list, "한계를 넘었는데 리스트가 나왔다")
        XCTAssertEqual(error?.code, MTParseErrors.nestingTooDeep.rawValue,
                       "다른 오류로 끝났다: \(error?.localizedDescription ?? "nil")")
    }

    /// 백그라운드 스레드의 좁은 스택(512KB)에서도 죽지 않는다 — 앱이 실제로 렌더하는 곳.
    func testDeepNestingOnNarrowStack() {
        let thread = Thread {
            var error: NSError?
            _ = MTMathListBuilder.build(fromString: self.deepBraces(5000), error: &error)
            XCTAssertEqual(error?.code, MTParseErrors.nestingTooDeep.rawValue)
        }
        thread.stackSize = 512 * 1024
        let done = expectation(description: "narrow stack parse")
        let observer = Thread { thread.start(); while !thread.isFinished { usleep(1000) }; done.fulfill() }
        observer.start()
        wait(for: [done], timeout: 20)
    }

    /// 분수 중첩도 같은 방식으로 막힌다(그룹만이 아니라 명령 인자 경로도 재귀한다).
    func testDeepFractionNestingReportsError() {
        let n = 2000
        let latex = String(repeating: #"\frac{"#, count: n) + "x"
            + String(repeating: "}{y}", count: n)
        var error: NSError?
        let list = MTMathListBuilder.build(fromString: latex, error: &error)
        XCTAssertNil(list)
        XCTAssertEqual(error?.code, MTParseErrors.nestingTooDeep.rawValue)
    }

    /// 사람이 쓰는 수준의 중첩은 **막히지 않아야** 한다 — 상한이 너무 낮으면 그게 또 버그다.
    func testRealisticNestingStillParses() {
        let cases = [
            // 3단 연분수 — 실제 교재에 나오는 가장 깊은 축
            #"\frac{1}{1+\frac{1}{1+\frac{1}{1+\frac{1}{x}}}}"#,
            // 첨자의 첨자의 첨자
            #"x^{y^{z^{w^{v}}}}"#,
            // 루트 안 루트 안 분수
            #"\sqrt{1+\sqrt{1+\sqrt{1+\frac{a}{b}}}}"#,
            // 괄호 중첩 + 행렬
            #"\left(\frac{\begin{pmatrix}a&b\\c&d\end{pmatrix}}{\left[\frac{x}{y}\right]}\right)"#,
            // CJK 혼합
            #"\frac{\text{운동 에너지}}{\frac{1}{2}mv^2} + \sqrt{\text{속도}^2}"#,
        ]
        for latex in cases {
            var error: NSError?
            let list = MTMathListBuilder.build(fromString: latex, error: &error)
            XCTAssertNotNil(list, "정상 수식이 막혔다: \(latex) — \(error?.localizedDescription ?? "")")
            XCTAssertNil(error, "정상 수식에서 오류: \(latex)")
        }
    }

    /// 깊이 카운터가 형제 그룹 사이에서 새지 않는지 — 옆으로 긴 수식은 깊이가 아니다.
    func testWideExpressionIsNotTreatedAsDeep() {
        // 그룹 200개를 **나란히** 놓는다. 깊이는 1이지 200이 아니다.
        let latex = String(repeating: "{x}", count: 200)
        var error: NSError?
        let list = MTMathListBuilder.build(fromString: latex, error: &error)
        XCTAssertNotNil(list, "형제 그룹이 깊이로 오산됐다: \(error?.localizedDescription ?? "")")
        XCTAssertNil(error)
    }

    /// 상한은 소비자가 조절할 수 있어야 한다.
    func testLimitIsConfigurable() {
        let original = MTMathListBuilder.maxNestingDepth
        defer { MTMathListBuilder.maxNestingDepth = original }

        MTMathListBuilder.maxNestingDepth = 5
        var error: NSError?
        _ = MTMathListBuilder.build(fromString: deepBraces(20), error: &error)
        XCTAssertEqual(error?.code, MTParseErrors.nestingTooDeep.rawValue)

        MTMathListBuilder.maxNestingDepth = 200
        var error2: NSError?
        let list = MTMathListBuilder.build(fromString: deepBraces(20), error: &error2)
        XCTAssertNotNil(list, "상한을 올렸는데도 막혔다")
        XCTAssertNil(error2)
    }
}
