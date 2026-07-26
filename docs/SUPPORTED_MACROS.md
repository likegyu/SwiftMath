# 지원 매크로 (likegyu/SwiftMath 포크)

이 포크가 **무엇을 그릴 수 있고 무엇을 못 그리는지** 한곳에 모은 문서다.
LaTeX를 생성하는 쪽(사람이든 LLM이든)이 참고할 목적으로 쓴다.

수치는 실측이다. 기호 표에 491개, 별칭 62개가 등록돼 있고, 여기에 구조 명령·환경·악센트가
더해진다. 대학 STEM 강의에서 쓰이는 매크로 136개를 추려 실제로 파싱시켜 본 결과
**126개(93%)가 동작**했다. 못 하는 것은 아래 "지원하지 않음"에 전부 적었다.

> 검증 방식: `Tests/SwiftMathTests/SyntaxCoverageTests.swift` 가 문법 56종을
> **로마자와 CJK 두 벌**로 만들어 ① display·text 두 스타일 조판 ② 파싱 중 CJK 유실 여부
> ③ CJK가 조판 결과에서 실제로 자리를 차지하는지 ④ LaTeX로 되돌린 문자열의 재파싱을
> 확인한다. 이 문서와 코드가 어긋나면 그 테스트가 먼저 깨진다.

---

## 지원하지 않음 (이것만 피하면 된다)

| 매크로 | 이유 | 대신 |
|---|---|---|
| `\tag{}` `\intertext{}` | 번호·본문 삽입 — 앱에 번호를 붙일 자리가 없다 | 없어도 된다 |
| `\mathclap{}` `\prescript{}` `\genfrac{}` | mathtools 세부 조판 | 드물다 |
| `\chemfig{}` (2차원 구조식) | 결합각·고리를 그리는 별도 그리기 언어 | `\ce{}` 로 선형 표기 |
| `\sideset` `\mathchoice` `\buildrel` `\pod` | plain TeX·amsmath 세부 조판 | 드물다 |
| `\root n \of x` | plain TeX 표기 | `\sqrt[n]{x}` |

**모르는 명령을 만나면** 파서가 `Invalid command \foo` 오류를 낸다. 소비자 앱은 보통
그 명령만 지우고 다시 시도하거나(자가치유), 그래도 안 되면 원문을 그대로 보여준다.
즉 미지원 매크로 하나가 수식 전체를 날리지는 않되, **그 장식의 의미는 사라진다.**

---

## 지원함

### 구조

`\frac` `\dfrac` `\tfrac` `\cfrac` · `\binom` `\dbinom` `\tbinom` · `\atop`
`\sqrt{}` `\sqrt[n]{}` · `x^{}` `x_{}` (중첩 가능) · `\limits` `\nolimits`
`\displaystyle` `\textstyle` `\scriptstyle` `\scriptscriptstyle`

### 위·아래 쌓기

`\overset{위}{본체}` `\underset{아래}{본체}` `\stackrel{위}{본체}` `\substack{a \\ b}`

간격 등급은 본체를 물려받는다(amsmath `\binrel@`와 같다) — `\overset{?}{=}` 는 여전히
관계연산자로 취급돼 앞뒤가 벌어지고, `\overset{a}{x}` 는 보통 원자다.
`\stackrel` 은 정의상 항상 관계연산자다.

### 색

`\textcolor{색}{내용}` `\color{색}{내용}` `\colorbox{색}{내용}`

색 이름은 xcolor 기본 팔레트(`red` `blue` `green` `cyan` `magenta` `yellow` `black` `white`
`gray`/`grey` `darkgray` `lightgray` `brown` `lime` `olive` `orange` `pink` `purple` `teal`
`violet`)와 `#RRGGBB` 를 받는다. 모르는 이름이면 **색만 포기하고 내용은 그대로 그린다.**

색이 걸린 부분은 바깥에서 수식 전체 색을 덮어써도 살아남고, 색 안에서도 줄바꿈이 된다.

### 덧그리는 장식

`\boxed{}` `\fbox{}` `\framebox{}` — 테두리 (여백 0.2em)
`\cancel{}` (↗) `\bcancel{}` (↘) `\xcancel{}` (×) — 취소선, 크기를 바꾸지 않는다
`\overline{}` `\underline{}`

### 늘어나는 중괄호·악센트·화살표

`\overbrace{내용}^{라벨}` `\underbrace{내용}_{라벨}`
`\overparen{}` `\underparen{}` `\overbracket{}` `\underbracket{}`
`\underrightarrow{}` `\underleftarrow{}` `\underleftrightarrow{}`

중괄호는 내용 폭에 맞춰 늘어난다. 폰트의 가로 변형 8단계(라틴 모던 기준 4.01em)를 쓰고,
그보다 넓으면 가장 큰 변형을 가로로 늘인다 — 아주 넓어지면 끝 곡선이 다소 퍼진다.
뒤따르는 `^`(overbrace) · `_`(underbrace)는 **중괄호 위/아래 가운데** 라벨이 된다.

`\xrightarrow[아래]{위}` `\xleftarrow` `\xleftrightarrow` `\xRightarrow` `\xhookrightarrow`
`\xmapsto` `\xrightleftharpoons` `\xlongequal`

화살표는 **라벨 폭에 맞춰** 늘어난다. 글리프를 늘이지 않고 축선과 촉을 직접 그리므로
어떤 폭에서도 획 굵기가 일정하다(폰트의 화살표 가로 변형은 1.46em 이 한계라 못 쓴다).

### 자리 맞춤

`\phantom{}` (폭·높이 유지, 안 그림) `\hphantom{}` (폭만) `\vphantom{}` (높이만)
`\smash{}` (그리되 높이 0으로 신고) `\mathstrut` (`\vphantom{(}`)

### 악센트

`\vec` `\hat` `\bar` `\dot` `\ddot` `\dddot` `\ddddot` `\tilde` `\check` `\breve`
`\acute` `\grave` `\mathring` `\widehat` `\widetilde` `\widecheck`
`\overrightarrow` `\overleftarrow` `\overleftrightarrow`

### 구분자

`\left` … `\right` 로 감싸면 내용 높이에 맞춰 늘어난다.
`(` `)` `[` `]` `\{` `\}` `\langle` `\rangle` `\lfloor` `\rfloor` `\lceil` `\rceil`
`|` `\|` `\vert` `\Vert` `\lvert` `\rvert` `\lVert` `\rVert`
`\uparrow` `\downarrow` `\updownarrow` (및 대문자형) `\lgroup` `\rgroup` `\backslash` `.`

### 환경

`align` `aligned` `alignat` `flalign` `equation` `multline` `gather` `gathered`
`cases` `dcases` `rcases` `displaylines` `eqnarray` `split` `eqalign`
(별표형 `align*` 등은 번호를 안 붙인다는 뜻뿐이라 같게 조판한다)
`matrix` `pmatrix` `bmatrix` `Bmatrix` `vmatrix` `Vmatrix` `smallmatrix`
(별표형 `matrix*` 등은 대괄호로 열 정렬을 받는다)

`\begin{array}{lcr}` · `\begin{subarray}{c}` — 열마다 `l`·`c`·`r` 로 정렬을 지정한다.
세로줄(`|`)과 `@{}`·`p{}` 는 **읽고 무시한다** — 표에 세로줄을 그릴 방법이 없어서,
받아 봐야 못 지키느니 내용을 살리는 쪽을 골랐다. 열 수로는 세지 않는다.

### 큰 연산자

`\sum` `\prod` `\coprod` `\int` `\iint` `\iiint` `\oint` `\idotsint`
`\bigcup` `\bigcap` `\bigoplus` `\bigotimes` `\bigodot` `\biguplus` `\bigvee` `\bigwedge` `\bigsqcup`
`\lim` `\limsup` `\liminf` `\varlimsup` `\varliminf` `\varprojlim` `\varinjlim` `\injlim` `\projlim` `\plim`
`\sup` `\inf` `\max` `\min` `\argmax` `\argmin` `\det` `\dim` `\ker` `\deg` `\gcd` `\Pr` `\arg` `\hom`
`\sin` `\cos` `\tan` `\sec` `\csc` `\cot` `\cosec` 및 `arc`·`h` 변형 · `\log` `\ln` `\lg` `\exp`
`\bmod` `\pmod{}` `\mod` · `\operatorname{}`

### 글꼴

`\mathbf` `\mathit` `\mathrm` `\mathnormal` `\mathbb` `\mathds` `\mathcal` `\mathscr` `\scr`
`\mathfrak` `\mathsf` `\mathsfit` `\mathtt` `\bm` `\boldsymbol` `\pmb`
`\text` `\textrm` `\textbf` `\textit` `\texttt` `\textsf` `\textnormal` `\textup` `\textmd`
`\textsl` `\textsc` `\emph` `\mbox` `\ensuremath`
(작은대문자·기울임체는 이 조판기에 없어 가장 가까운 서체로 떨어진다)

### 기호 (491개 + 별칭 62개)

그리스 대소문자 전체와 `\var` 변형, 관계·이항연산·화살표·집합·논리·기하 기호 일습.
자주 쓰는 것 중 이 포크에서 **새로 추가된 것**들:

`\therefore` `\because` `\vDash` `\models` `\coloneqq` `\lll` `\ggg`
`\rightleftharpoons` `\leftrightharpoons` `\triangleleft` `\triangleright`
`\blacksquare` `\square` `\checkmark` `\complement` `\natural` `\dag`
`\permil` `\perthousand` · 대문자 그리스 `\Alpha`…`\Chi`
이탤릭 대문자 그리스 `\varGamma` `\varDelta` `\varTheta` `\varLambda` `\varXi` `\varPi`
`\varSigma` `\varUpsilon` `\varPhi` `\varPsi` `\varOmega`
곡면·부피 적분 `\oiint` `\oiiint`

`\not` 은 `\not\in` 같은 명령형과 **`\not=` 같은 맨 문자형을 모두** 받는다.

### 간격

`\,` `\:` `\;` `\!` `\quad` `\qquad` `\ ` `~`
`\thinspace` `\medspace` `\thickspace` `\enspace` `\negthinspace`

명시적 간격도 받는다 — `\hspace{1cm}` `\kern 5pt` `\hskip 3pt` `\mspace{9mu}` `\mkern 18mu`.
`pt`·`cm` 같은 절대 단위는 1em ≈ 10pt 로 **근사해서** mu 로 옮긴다(이 조판기의 간격이 mu 기반이라
정확히 옮길 수 없다). `\hfill` 은 인라인 수식에서 의미가 없어 `\quad` 로 둔다.

### physics 패키지

`\dv{f}{x}` `\dv[2]{f}{x}` `\pdv{f}{x}` — 미분·편미분
`\abs{}` `\norm{}` `\ceil{}` `\floor{}` `\set{}` — 자동 크기 구분자
`\bra{}` `\ket{}` `\braket{}{}` `\ev{}` `\comm{}{}` `\acomm{}{}` — 양자역학 표기
`\grad` `\divergence` `\curl` `\laplacian` — 벡터 미분
`\middle` 는 받되 **늘어나지는 않는다**(보통 크기 구분자로 둔다).

### 사용자 매크로

`\newcommand{\R}{\mathbb{R}}` `\newcommand{\f}[1]{f(#1)}` `\def\x{y}`
`\renewcommand` `\providecommand` · `\DeclareMathOperator{\tr}{tr}` (별표형은 첨자를 위아래로)

인자는 `#1`…`#9`. 정의는 같은 문자열 안에서만 유효하다.
**펼치기 깊이 상한 20** — `\def\x{\x}` 같은 자기 참조나 상호 재귀가 들어와도 무한히 돌지 않고
`nestingTooDeep` 오류로 끝난다. 신뢰할 수 없는 입력을 렌더하는 이상 필요한 방어다.

### 간격 등급 지정

`\mathord{}` `\mathbin{}` `\mathrel{}` `\mathop{}` `\mathopen{}` `\mathclose{}` `\mathpunct{}`

원자 하나짜리 그룹에만 적용된다. 여럿이면 무엇의 등급인지 모호해 건드리지 않는다.

### 관례 연산자

표준 LaTeX 에는 없지만 `\DeclareMathOperator` 로 흔히 정의해 쓰는 이름들.
LLM 이 관례대로 그냥 쓰는 일이 잦아 넣었다:

`\tr` `\rank` `\diag` `\sgn` `\Var` `\Cov` `\Corr` `\Res` `\Span` `\im` `\id`
`\Aut` `\End` `\Ext` `\Tor` `\Ker` `\coker` `\Hom` `\adj` `\erf` `\erfc` `\sinc`

`\notag`·`\nonumber` 는 **조용히 무시한다** — 오류를 내면 수식 하나가 통째로 날아간다.

### 화학식 (mhchem 서브셋)

`\ce{H2SO4}` `\ce{2H2 + O2 -> 2H2O}` `\ce{N2 + 3H2 <=> 2NH3}`

아래첨자(`H2O`) · 계수(`2H2O`) · 전하(`Ca^2+` `SO4^2-`) · 상태(`(aq)` `(s)` `(l)` `(g)`)
· 화살표(`->` `<-` `<->` `<=>`, `->[위][아래]` 라벨) · 수화물(`*`) · 침전 `v` · 기체 `^`
· 동위원소(`^{227}_{90}Th`) · `$…$` 수식 삽입.

`+` 는 mhchem 규칙대로 **공백으로 가른다** — `H+` 는 전하(H⁺), `A + B` 는 구분자.
결합선 `-` `=` `#` 은 원자에 바짝 붙는다(관계연산자 간격을 주지 않는다).

### 단위 (siunitx 서브셋)

`\SI{9.8}{\meter\per\second\squared}` `\si{\ohm}` `\num{6.022e23}` `\SIrange{1}{10}{\meter}`

SI 기본·유도 단위와 접두어 전체, `\per` `\squared` `\cubed`, 지수 표기(`1.5e3` → 1.5×10³).
`\qty` `\unit` (siunitx v3 이름)도 같이 받는다.

두 문법 모두 **LaTeX 로 옮겨 일반 파서에 태운다.** 옮길 수 없는 입력은 오류를 내지 않고
정립 텍스트로 흘려보낸다 — 화학식 하나 때문에 수식 전체를 잃지 않는 게 우선이다.

### CJK

수식 모드 안에서 한글·한자·가나를 **그대로** 쓸 수 있다. `\text{}` 로 감쌀 필요가 없다.

```latex
E_{운동} = \frac{1}{2}mv^2
\sum_{\substack{속도>0 \\ 가속도<0}} \text{힘}
```

서체는 기본적으로 CoreText 시스템 폴백이 고르는데, Apple 플랫폼에는 한글·중문 세리프가
없어 수학 폰트(세리프)와 어긋난다. `SwiftMathCJKFonts` 모듈을 링크하면 번들 명조로 맞출 수 있다:

```swift
import SwiftMathCJKFonts
let font = MTFontManager.fontManager.latinModernFont(withSize: 20)!
    .copy(withCJKSerif: .korean, .simplifiedChinese)
```

---

## 안전장치

- **재귀 깊이 상한** `MTMathListBuilder.maxNestingDepth` (기본 100). 넘으면 스택 오버플로로
  프로세스가 죽는 대신 `MTParseErrors.nestingTooDeep` 오류를 낸다. 신뢰할 수 없는 입력
  (LLM이 만든 LaTeX)을 렌더할 때 필요하다.
- 어긋난 중괄호·짝 없는 `\left` 등은 오류로 돌아오며 크래시하지 않는다.

## 알려진 한계

- **스타일 명령이 크기를 바꾸지 않는다.** `\scriptstyle`·`\displaystyle` 은 파싱되고
  추적되지만 글자 크기에 반영되지 않는다(실측: `{\scriptstyle i<n}` 과 `i<n` 의 폭이 같고
  `smallmatrix` 도 `matrix` 와 같다). 첨자·분수처럼 **조판기가 직접 크기를 정하는 경로**는
  정상이므로, `\sum_{\begin{subarray}…}` 같은 실사용은 제대로 작게 나온다.
