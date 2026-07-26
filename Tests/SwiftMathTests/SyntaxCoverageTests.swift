import XCTest
@testable import SwiftMath
import SwiftMathCJKFonts

/// 지원하는 LaTeX 문법을 **한 벌씩 전부** 로마자와 CJK 양쪽으로 조판해 본다.
///
/// 개별 기능 테스트가 각자 통과해도, 실제 문서는 이것들을 섞어 쓴다. 여기서는
/// "문법 하나 × 로마자/CJK" 조합을 훑어 하나라도 파싱이나 조판에서 무너지지 않는지 본다.
/// 앞서 실제 업로드에서 깨진 사례가 전부 "개별로는 되는데 섞으니 안 되는" 형태였다.
final class SyntaxCoverageTests: XCTestCase {

    /// (분류, 로마자 예시, 같은 문법의 CJK 예시)
    static let matrix: [(String, String, String)] = [
        // 기본 구조
        ("분수", #"\frac{a}{b}"#, #"\frac{질량}{부피}"#),
        ("중첩 분수", #"\frac{1}{1+\frac{1}{x}}"#, #"\frac{1}{1+\frac{1}{속도}}"#),
        ("이항계수", #"\binom{n}{k}"#, #"\binom{전체}{선택}"#),
        ("근호", #"\sqrt{x}"#, #"\sqrt{면적}"#),
        ("n제곱근", #"\sqrt[3]{x}"#, #"\sqrt[3]{부피}"#),
        ("위첨자", #"x^{2}"#, #"속도^{2}"#),
        ("아래첨자", #"x_{i}"#, #"에너지_{운동}"#),
        ("위아래첨자", #"x_i^2"#, #"질량_{초기}^{2}"#),
        ("중첩 첨자", #"x^{y^{z}}"#, #"가^{나^{다}}"#),

        // 큰 연산자
        ("합", #"\sum_{i=1}^{n} i"#, #"\sum_{i=1}^{n} 항_i"#),
        ("적분", #"\int_0^1 f(x)dx"#, #"\int_0^1 함수(x)dx"#),
        ("이중적분", #"\iint_D f"#, #"\iint_D 밀도"#),
        ("곱", #"\prod_{i=1}^n a_i"#, #"\prod_{i=1}^n 계수_i"#),
        ("극한", #"\lim_{x \to 0} f(x)"#, #"\lim_{x \to 0} 함수(x)"#),
        ("상한/하한", #"\sup_{x} f \quad \inf_{x} f"#, #"\sup_{x} 값 \quad \inf_{x} 값"#),

        // 구분자
        ("자동 괄호", #"\left( \frac{a}{b} \right)"#, #"\left( \frac{질량}{부피} \right)"#),
        ("대괄호·중괄호", #"\left[ x \right] \left\{ y \right\}"#, #"\left[ 가 \right] \left\{ 나 \right\}"#),
        ("절댓값·노름", #"\left| x \right| \; \|v\|"#, #"\left| 오차 \right| \; \|벡터\|"#),
        ("바닥·천장", #"\lfloor x \rfloor \lceil y \rceil"#, #"\lfloor 값 \rfloor \lceil 값 \rceil"#),
        ("꺾쇠", #"\langle u, v \rangle"#, #"\langle 벡터, 벡터 \rangle"#),

        // 환경
        ("정렬", "\\begin{aligned} a &= b \\\\ c &= d \\end{aligned}",
                "\\begin{aligned} 좌변 &= 우변 \\\\ 가 &= 나 \\end{aligned}"),
        ("경우 나눔", "\\begin{cases} 1 & x>0 \\\\ 0 & x\\le 0 \\end{cases}",
                     "\\begin{cases} 양수 & x>0 \\\\ 음수 & x\\le 0 \\end{cases}"),
        ("행렬", "\\begin{pmatrix} a & b \\\\ c & d \\end{pmatrix}",
                "\\begin{pmatrix} 가 & 나 \\\\ 다 & 라 \\end{pmatrix}"),
        ("행렬식", "\\begin{vmatrix} a & b \\\\ c & d \\end{vmatrix}",
                  "\\begin{vmatrix} 가 & 나 \\\\ 다 & 라 \\end{vmatrix}"),

        // 장식 (이번에 정식 조판된 것들)
        ("overset", #"\overset{\text{def}}{=}"#, #"\overset{정의}{=}"#),
        ("underset", #"\underset{n\to\infty}{\lim}"#, #"\underset{극한}{\lim}"#),
        ("stackrel", #"A \stackrel{f}{\to} B"#, #"가 \stackrel{사상}{\to} 나"#),
        ("substack", #"\sum_{\substack{i<n \\ j<m}} a"#, #"\sum_{\substack{속도>0 \\ 가속도<0}} 힘"#),
        ("boxed", #"\boxed{x=5}"#, #"\boxed{정답: x=5}"#),
        ("cancel", #"\frac{\cancel{x}y}{\cancel{x}}"#, #"\frac{\cancel{속도}가}{\cancel{속도}}"#),
        ("bcancel/xcancel", #"\bcancel{a}\xcancel{b}"#, #"\bcancel{가}\xcancel{나}"#),
        ("윗줄·밑줄", #"\overline{AB} \; \underline{CD}"#, #"\overline{선분} \; \underline{강조}"#),
        ("악센트", #"\vec{v} \hat{x} \bar{y} \dot{z} \tilde{w}"#, #"\vec{속도} \hat{방향} \bar{평균}"#),
        ("넓은 악센트", #"\widehat{ABC} \widetilde{XYZ}"#, #"\widehat{각도} \widetilde{근사}"#),

        // 글꼴
        ("굵게·기울임", #"\mathbf{A} \mathit{B}"#, #"\mathbf{A}가 \mathit{B}나"#),
        ("칠판체·필기체", #"\mathbb{R} \mathcal{L} \mathscr{F}"#, #"\mathbb{R}의 원소 \mathcal{L}"#),
        ("고딕체·산세리프", #"\mathfrak{g} \mathsf{T}"#, #"\mathfrak{g}군 \mathsf{T}"#),
        ("텍스트", #"\text{if } x>0"#, #"\text{만약 } x>0 \text{ 이면}"#),

        // 기호
        ("그리스", #"\alpha\beta\gamma\Delta\Omega\varepsilon"#, #"\alpha각 \Delta변화 \Omega저항"#),
        ("관계", #"\le \ge \ne \approx \equiv \sim \propto"#, #"길이 \le 폭 \approx 높이"#),
        ("집합", #"A \cup B \cap C \subset D \in E \notin F"#, #"집합 \cup 집합 \subset 전체"#),
        ("논리", #"\forall \exists \neg \land \lor \implies \iff"#, #"\forall 원소 \exists 해"#),
        ("화살표", #"\to \gets \Rightarrow \Leftrightarrow \mapsto \rightleftharpoons"#,
                  #"원인 \to 결과 \Rightarrow 결론"#),
        ("therefore/because", #"\therefore x=1 \quad \because y=2"#, #"\therefore 참 \quad \because 가정"#),
        ("연산", #"\pm \mp \times \div \cdot \ast \oplus \otimes"#, #"가 \times 나 \div 다"#),
        ("점", #"\cdots \ldots \vdots \ddots"#, #"항 \cdots 항"#),
        ("무한·미분", #"\infty \partial \nabla \prime"#, #"\partial 함수 / \partial 시간"#),
        ("이름 연산자", #"\sin\cos\tan\log\ln\exp\max\min\gcd\deg\bmod"#, #"\log 값 \max 최대"#),
        ("각도·수직", #"\angle ABC \perp \parallel \cong"#, #"\angle 각 \perp 수직"#),

        // 간격
        ("간격 명령", #"a\,b\;c\quad d\qquad e\!f"#, #"가\,나\;다\quad 라"#),
        ("공백 명령", #"a\ b \thinspace c"#, #"가\ 나 \thinspace 다"#),

        // 혼합 — 실제 문서에서 나오는 형태
        ("물리 공식", #"E_{k} = \frac{1}{2}mv^{2}"#, #"E_{운동} = \frac{1}{2}mv^{2}"#),
        ("화학 평형", #"\text{H}_2\text{O} \rightleftharpoons \text{H}^+ + \text{OH}^-"#,
                     #"\text{물} \rightleftharpoons \text{수소이온} + \text{수산화이온}"#),
        ("통계", #"\bar{x} = \frac{1}{n}\sum_{i=1}^{n} x_i"#,
                #"\bar{평균} = \frac{1}{n}\sum_{i=1}^{n} 표본_i"#),
        ("노름 기호", #"\lVert v \rVert + \lvert x \rvert"#, #"\lVert 벡터 \rVert"#),
        ("이항 변형", #"\dbinom{n}{k} \tbinom{n}{k}"#, #"\dbinom{전체}{선택}"#),
        ("역·순 극한", #"\varprojlim_{n} A_n \quad \varinjlim_{n} B_n"#, #"\varprojlim_{n} 군_n"#),
        ("천분율", #"5\permil"#, #"농도 5\permil"#),
        ("긴 혼합식", #"\int_{0}^{\infty} \frac{\sin x}{x} dx = \frac{\pi}{2}"#,
                    #"\int_{0}^{\infty} \frac{\text{진폭}(t)}{t} dt = \frac{\pi}{2} \text{ (수렴)}"#),
    ]

    private func font(_ size: CGFloat = 20) throws -> MTFont {
        try XCTUnwrap(MTFontManager.fontManager.latinModernFont(withSize: size))
            .copy(withCJKSerif: .korean, .simplifiedChinese, .japanese)
    }

    /// 전부 파싱되고 조판되는가. 실패한 항목을 한 번에 모아 보고한다.
    func testAllSyntaxParsesAndTypesets() throws {
        let font = try self.font()
        var failures: [String] = []

        for (label, latin, cjk) in Self.matrix {
            for (variant, latex) in [("로마자", latin), ("CJK", cjk)] {
                var error: NSError?
                guard let list = MTMathListBuilder.build(fromString: latex, error: &error),
                      error == nil else {
                    failures.append("[\(label)/\(variant)] 파싱 실패: \(error?.localizedDescription ?? "nil")\n    \(latex)")
                    continue
                }
                guard let display = MTTypesetter.createLineForMathList(list, font: font, style: .display) else {
                    failures.append("[\(label)/\(variant)] 조판 실패\n    \(latex)")
                    continue
                }
                if display.width <= 0 {
                    failures.append("[\(label)/\(variant)] 폭이 0\n    \(latex)")
                }
                if display.ascent + display.descent <= 0 {
                    failures.append("[\(label)/\(variant)] 높이가 0\n    \(latex)")
                }
            }
        }

        XCTAssertTrue(failures.isEmpty,
                      "\(failures.count)개 실패\n" + failures.joined(separator: "\n"))
    }

    /// 파싱 과정에서 한글이 **한 글자도 사라지지 않는지** 확인한다.
    ///
    /// 예전에 skipSpaces 가 CJK를 삼켜 한글이 통째로 없어진 적이 있다. 폭으로 재면 분수처럼
    /// 위아래로 쌓이는 구조에서 오탐이 나므로, 파싱 결과를 다시 문자열로 뽑아 글자 수를
    /// 직접 센다. mathListToString 은 원자 트리 전체를 훑으므로 어디에 묻혀도 잡힌다.
    func testCJKSurvivesParsing() throws {
        func hangul(_ s: String) -> [Character] {
            s.filter { $0.unicodeScalars.allSatisfy { (0xAC00...0xD7A3).contains($0.value) } }
        }

        var losses: [String] = []
        for (label, _, cjk) in Self.matrix {
            let expected = hangul(cjk).sorted()
            guard !expected.isEmpty else { continue }

            var error: NSError?
            guard let list = MTMathListBuilder.build(fromString: cjk, error: &error), error == nil else {
                losses.append("[\(label)] 파싱 실패: \(cjk)"); continue
            }
            let actual = hangul(MTMathListBuilder.mathListToString(list)).sorted()
            if actual != expected {
                losses.append("[\(label)] 한글이 바뀌었다\n    기대: \(String(expected))"
                              + "\n    실제: \(String(actual))\n    입력: \(cjk)")
            }
        }
        XCTAssertTrue(losses.isEmpty, "\(losses.count)개\n" + losses.joined(separator: "\n"))
    }

    /// CJK가 조판 결과에서도 자리를 차지하는가 — 파싱은 됐는데 안 그려지는 경우를 잡는다.
    ///
    /// 같은 수식에서 한글만 뺀 것과 비교해, 한글이 있는 쪽이 **더 크기만 하면** 된다.
    /// 폭만 보면 안 되는 이유: `\underset{극한}{\lim}` 처럼 장식이 본체보다 좁으면 폭은
    /// 그대로고 높이만 는다(위아래로 쌓이는 구조의 폭은 합이 아니라 최댓값이다).
    func testCJKOccupiesSpace() throws {
        let font = try self.font()
        var suspicious: [String] = []

        for (label, _, cjk) in Self.matrix {
            let stripped = String(cjk.filter { ch in
                !ch.unicodeScalars.allSatisfy { (0xAC00...0xD7A3).contains($0.value) }
            })
            guard stripped != cjk else { continue }

            var e1: NSError?, e2: NSError?
            guard let withCJK = MTMathListBuilder.build(fromString: cjk, error: &e1), e1 == nil,
                  let without = MTMathListBuilder.build(fromString: stripped, error: &e2), e2 == nil,
                  let a = MTTypesetter.createLineForMathList(withCJK, font: font, style: .display),
                  let b = MTTypesetter.createLineForMathList(without, font: font, style: .display)
            else { continue }   // 한글을 빼면 문법이 깨지는 예시는 이 검사 대상이 아니다

            let grewWider = a.width > b.width
            let grewTaller = (a.ascent + a.descent) > (b.ascent + b.descent)
            if !grewWider && !grewTaller {
                suspicious.append("[\(label)] 한글이 조판 결과에 안 나타났다 "
                                  + "(폭 \(String(format: "%.1f", a.width))/\(String(format: "%.1f", b.width))pt, "
                                  + "높이 \(String(format: "%.1f", a.ascent + a.descent))/\(String(format: "%.1f", b.ascent + b.descent))pt)"
                                  + "\n    \(cjk)")
            }
        }
        XCTAssertTrue(suspicious.isEmpty, "\(suspicious.count)개\n" + suspicious.joined(separator: "\n"))
    }

    /// 모든 항목이 인라인(text) 스타일에서도 조판된다 — 앱은 두 스타일을 다 쓴다.
    func testAllSyntaxInTextStyle() throws {
        let font = try self.font(17)
        var failures: [String] = []
        for (label, latin, cjk) in Self.matrix {
            for (variant, latex) in [("로마자", latin), ("CJK", cjk)] {
                var error: NSError?
                guard let list = MTMathListBuilder.build(fromString: latex, error: &error), error == nil,
                      let d = MTTypesetter.createLineForMathList(list, font: font, style: .text),
                      d.width > 0
                else { failures.append("[\(label)/\(variant)] 인라인 조판 실패: \(latex)"); continue }
            }
        }
        XCTAssertTrue(failures.isEmpty, failures.joined(separator: "\n"))
    }

    /// LaTeX 로 되돌렸다가 다시 읽어도 무너지지 않는다.
    func testRoundTripSurvives() throws {
        var failures: [String] = []
        for (label, latin, cjk) in Self.matrix {
            for (variant, latex) in [("로마자", latin), ("CJK", cjk)] {
                var error: NSError?
                guard let list = MTMathListBuilder.build(fromString: latex, error: &error), error == nil
                else { continue }
                let out = MTMathListBuilder.mathListToString(list)
                var reError: NSError?
                if MTMathListBuilder.build(fromString: out, error: &reError) == nil || reError != nil {
                    failures.append("[\(label)/\(variant)] 되돌린 문자열을 다시 못 읽음\n    원본: \(latex)\n    출력: \(out)\n    오류: \(reError?.localizedDescription ?? "nil")")
                }
            }
        }
        XCTAssertTrue(failures.isEmpty, "\(failures.count)개\n" + failures.joined(separator: "\n"))
    }
}
