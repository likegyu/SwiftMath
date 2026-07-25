#if os(macOS)
import XCTest
import AppKit
@testable import SwiftMath

/// 시각 회귀 도구 — 대표 수식을 한 장의 PNG로 모아 굽는다.
///
/// 자동 단정으로는 "글리프가 겹쳤다·기준선이 어긋났다·두부(.notdef)가 떴다"를 잡을 수 없다.
/// 사람이(또는 이미지를 볼 수 있는 에이전트가) 한 장을 훑어 판단하는 편이 훨씬 촘촘하다.
/// 렌더 자체가 실패하면 테스트가 깨지므로 회귀 감지도 겸한다.
///
/// 실행:  swift test --filter SpecSheetTests
/// 산출:  /tmp/swiftmath-specsheet.png (경로는 실행 로그에 찍힌다)
final class SpecSheetTests: XCTestCase {

    /// (분류, 라벨, LaTeX, 이래야 정상)
    private static let samples: [(String, String, String, String)] = [
        // ── 기본 ────────────────────────────────────────────────────────────
        ("기본", "분수·루트", #"\frac{-b \pm \sqrt{b^2-4ac}}{2a}"#,
         "분수 막대가 분자·분모 중앙, 루트 갈고리가 내용 전체를 덮음"),
        ("기본", "중첩 분수", #"\frac{1}{1+\frac{1}{1+\frac{1}{x}}}"#,
         "안쪽 분수가 단계적으로 작아짐"),
        ("기본", "첨자 조합", #"x_i^2 + y^{n+1}_{j,k}"#,
         "위·아래 첨자가 겹치지 않고 크기가 축소됨"),
        // ── 큰 연산자 ───────────────────────────────────────────────────────
        ("연산자", "합·극한", #"\sum_{i=1}^{n} i = \frac{n(n+1)}{2}"#,
         "∑ 위아래로 첨자, 기호가 충분히 큼"),
        ("연산자", "적분", #"\int_{0}^{\infty} e^{-x^2}\,dx = \frac{\sqrt{\pi}}{2}"#,
         "적분 기호가 크고 첨자는 옆에 붙음"),
        ("연산자", "극한·곱", #"\lim_{x \to 0}\frac{\sin x}{x} = 1, \quad \prod_{k=1}^{n} k"#,
         "lim 아래 첨자, ∏ 위아래 첨자"),
        // ── 구분자 ──────────────────────────────────────────────────────────
        ("구분자", "자동 크기", #"\left( \frac{a}{b} \right)^2 \left[ \frac{c}{d} \right]"#,
         "괄호 높이가 분수 높이에 맞게 늘어남"),
        ("구분자", "절댓값·노름", #"\left| \frac{x}{y} \right| \quad \left\| v \right\|"#,
         "세로 막대가 내용 높이에 맞음"),
        // ── 행렬·환경 ───────────────────────────────────────────────────────
        ("환경", "행렬", #"\begin{pmatrix} a & b \\ c & d \end{pmatrix}"#,
         "괄호가 2×2를 감싸고 열 간격 균일"),
        ("환경", "cases", #"f(x) = \begin{cases} x^2 & x > 0 \\ 0 & x \le 0 \end{cases}"#,
         "왼쪽 중괄호가 두 줄을 감쌈"),
        ("환경", "aligned", #"\begin{aligned} a &= b + c \\ d &= e \end{aligned}"#,
         "= 기호 세로 정렬"),
        // ── 폰트 스타일 ─────────────────────────────────────────────────────
        ("스타일", "칠판체·필기체", #"\mathbb{R} \subset \mathbb{C}, \; \mathcal{L}, \; \mathscr{E}"#,
         "ℝ ℂ 이중선, 필기체 L·E (두부 아님)"),
        ("스타일", "프락투어·굵게", #"\mathfrak{g} \oplus \mathfrak{h}, \; \bm{v} \cdot \mathbf{w}"#,
         "고딕체 g·h, 굵은 v·w"),
        ("스타일", "로만·타이프", #"\mathrm{d}x, \; \mathtt{code}, \; \mathsf{sans}"#,
         "각각 세리프·고정폭·산세리프"),
        // ── 악센트·화살표 ───────────────────────────────────────────────────
        ("악센트", "벡터·모자", #"\vec{v}, \; \hat{n}, \; \bar{x}, \; \tilde{a}, \; \dot{y}, \; \ddot{z}"#,
         "각 기호가 글자 위 중앙에 놓임"),
        ("화살표", "관계", #"a \to b \Rightarrow c \leftrightarrow d \mapsto e"#,
         "화살표 길이·굵기 일관"),
        // ── CJK (이 앱의 핵심) ──────────────────────────────────────────────
        ("CJK", "수식 모드 한글", #"속도 = 5"#,
         "한글이 보이고 두부가 아님 · 이탤릭이면 문제"),
        ("CJK", "한글 첨자", #"v_{초기} = 10"#,
         "첨자 한글이 축소되어 보임 · 잘리지 않음"),
        ("CJK", "혼합 수식", #"E_{운동} = \frac{1}{2}mv^2"#,
         "한글 첨자 + 라틴 변수 + 분수가 한 줄에 정합"),
        ("CJK", "text 명령", #"\text{속도} = 5\,\text{m/s}"#,
         "\\text 안 한글이 로만체로, 간격 정상"),
        ("CJK", "한글+라틴 간격", #"질량 m = 5kg"#,
         "한글과 라틴 사이 간격이 과하거나 붙지 않음"),
        ("CJK", "일본어·중국어", #"速度 = はやさ"#,
         "한자·가나 모두 렌더"),
        ("CJK", "블록 수식", #"W = \sqrt{\frac{2K_s(N_A+N_D)}{qN_AN_D}(V_{내부}-V_A)}"#,
         "루트 안 깊은 곳의 한글 첨자까지 보임"),
        // ── 긴 수식 ─────────────────────────────────────────────────────────
        ("길이", "긴 식", #"\nabla \times \vec{B} - \frac{1}{c}\frac{\partial \vec{E}}{\partial t} = \frac{4\pi}{c}\vec{J}"#,
         "잘림 없이 전부 그려짐"),
        // ── 신규 심볼 (2026-07-26 추가분) ───────────────────────────────────
        ("신규", "논리 관계", #"a \therefore b \because c \vDash d \Vdash e"#,
         "∴ ∵ ⊨ ⊩ — 크기가 주변 글자와 어울림(전각이면 오조판)"),
        ("신규", "대소 비교", #"a \lesssim b \gtrsim c \leqq d \geqq e \lll f \ggg g"#,
         "≲ ≳ ≦ ≧ ⋘ ⋙"),
        ("신규", "화학 평형", #"2H_2 + O_2 \rightleftharpoons 2H_2O"#,
         "⇌ 이중 화살표, 첨자 정상"),
        ("신규", "하푼·양방향", #"a \leftharpoonup b \rightharpoondown c \leftrightarrows d"#,
         "↼ ⇁ ⇆"),
        ("신규", "정의·근사", #"x \coloneqq y \eqqcolon z \approxeq w \triangleq v"#,
         "≔ ≕ ≊ ≜"),
        ("신규", "기호 모음", #"\blacksquare \checkmark \complement \natural \flat \sharp \dag"#,
         "■ ✓ ∁ ♮ ♭ ♯ †"),
        ("신규", "이항 연산", #"a \bigcirc b \Cap c \Cup d \triangleleft e \triangleright f"#,
         "◯ ⋒ ⋓ ◁ ▷ — 삼각형이 전각이 아님"),
        ("신규", "대문자 그리스", #"\Alpha \Beta \Epsilon \Zeta \Kappa \Mu \Rho \Chi"#,
         "Α Β Ε Ζ Κ Μ Ρ Χ (라틴 대문자와 구분되는 위치)"),
        ("신규", "이름 있는 연산자", #"\argmax_{x} f(x), \; a \bmod b, \; \varlimsup_{n} a_n"#,
         "arg max 아래 첨자, mod 는 첨자 없음"),
        ("신규", "공백 명령", #"a\,b\:c\;d\quad e\qquad f"#,
         "간격이 왼쪽부터 점점 넓어짐(전부 같으면 회귀)"),
        ("신규", "묶음 공백·악센트", #"a~b \quad \mathring{r} \; \dddot{x} \; \widecheck{y}"#,
         "a~b 가 ab 보다 넓고, 고리·세점·caron 이 글자 위에"),
    ]

    private static let fontSize: CGFloat = 22
    private static let labelFont = NSFont.systemFont(ofSize: 11)
    private static let noteFont = NSFont.systemFont(ofSize: 9)

    func testGenerateSpecSheet() throws {
        var rows: [(String, String, NSImage?, String, String?)] = []   // 분류, 라벨, 이미지, 기준, 오류

        for (category, label, latex, expectation) in Self.samples {
            var mathImage = MTMathImage(latex: latex, fontSize: Self.fontSize, textColor: .black)
            let (error, image) = mathImage.asImage()
            rows.append((category, label, image, expectation, error?.localizedDescription))
        }

        // 렌더 실패는 즉시 실패시킨다 — 스펙시트는 "보기 좋은 것"이 아니라 회귀 감지 도구다.
        let failures = rows.filter { $0.2 == nil }
        XCTAssertTrue(failures.isEmpty,
                      "렌더 실패: " + failures.map { "\($0.1)(\($0.4 ?? "?"))" }.joined(separator: ", "))

        let sheet = Self.compose(rows: rows)
        let url = URL(fileURLWithPath: "/tmp/swiftmath-specsheet.png")
        guard let tiff = sheet.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            XCTFail("PNG 인코딩 실패"); return
        }
        try png.write(to: url)
        print("SPEC SHEET → \(url.path)  (\(Int(sheet.size.width))×\(Int(sheet.size.height)))")
    }

    /// 각 수식을 라벨·기준과 함께 세로로 쌓아 한 장으로 만든다.
    private static func compose(rows: [(String, String, NSImage?, String, String?)]) -> NSImage {
        let margin: CGFloat = 16
        let labelColumn: CGFloat = 150
        let rowGap: CGFloat = 14
        let noteGap: CGFloat = 3

        var rowHeights: [CGFloat] = []
        var maxFormulaWidth: CGFloat = 0
        for row in rows {
            let h = max(row.2?.size.height ?? 20, 24)
            rowHeights.append(h + noteGap + 12)
            maxFormulaWidth = max(maxFormulaWidth, row.2?.size.width ?? 0)
        }
        let width = margin * 2 + labelColumn + max(maxFormulaWidth, 320) + 40
        let height = margin * 2 + rowHeights.reduce(0, +) + CGFloat(rows.count) * rowGap

        let sheet = NSImage(size: NSSize(width: width, height: height))
        sheet.lockFocus()
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()

        var y = height - margin
        var lastCategory = ""
        for (index, row) in rows.enumerated() {
            let (category, label, image, expectation, _) = row
            let rowHeight = rowHeights[index]
            y -= rowHeight

            // 분류가 바뀌면 구분선
            if category != lastCategory {
                NSColor.systemBlue.withAlphaComponent(0.25).setFill()
                NSRect(x: 0, y: y + rowHeight + rowGap * 0.35, width: width, height: 1).fill()
                lastCategory = category
            }

            ("[\(category)] \(label)" as NSString).draw(
                at: NSPoint(x: margin, y: y + rowHeight - 14),
                withAttributes: [.font: labelFont, .foregroundColor: NSColor.black])
            (expectation as NSString).draw(
                at: NSPoint(x: margin, y: y),
                withAttributes: [.font: noteFont, .foregroundColor: NSColor.gray])

            if let image {
                image.draw(at: NSPoint(x: margin + labelColumn, y: y + noteGap + 8),
                           from: .zero, operation: .sourceOver, fraction: 1.0)
            } else {
                ("RENDER FAILED" as NSString).draw(
                    at: NSPoint(x: margin + labelColumn, y: y + 8),
                    withAttributes: [.font: labelFont, .foregroundColor: NSColor.red])
            }
            y -= rowGap
        }
        sheet.unlockFocus()
        return sheet
    }
}
#endif
