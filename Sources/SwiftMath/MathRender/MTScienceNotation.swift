import Foundation

//
//  mhchem(`\ce`)과 siunitx(`\SI`)의 실용 서브셋.
//
//  둘 다 LaTeX 가 아니라 **별도 문법**이다. 렌더러를 하나 더 만드는 대신 일반 LaTeX 로
//  옮겨 기존 파서에 태운다. 이렇게 하면 첨자·화살표·정립 텍스트 같은 조판을 전부
//  재사용할 수 있고, 옮긴 결과가 곧 사람이 읽을 수 있는 설명이 된다.
//
//  완전한 구현이 아니다 — 강의 노트에 실제로 나오는 표기를 덮는 것이 목표다.
//  못 옮기는 입력은 **오류를 내지 않고 정립 텍스트로 흘려보낸다.** 화학식 하나 때문에
//  수식 전체가 사라지는 것보다 모양이 조금 어긋나는 편이 낫다.
//

// MARK: - mhchem

enum MTChemFormula {

    /// `\ce{…}` 의 내용을 LaTeX 로 옮긴다.
    static func toLatex(_ source: String) -> String {
        var out = ""
        let chars = Array(source)
        var i = 0
        // 원소 기호 바로 뒤에 오는 숫자만 아래첨자다. 계수(앞에 오는 숫자)는 보통 크기다.
        var previousWasFormulaUnit = false

        while i < chars.count {
            let c = chars[i]

            // 1) 화살표 — 긴 것부터 본다.
            if let (arrow, length) = matchArrow(chars, at: i) {
                i += length
                var above = "", below = ""
                // ->[위] 또는 ->[아래][위] — mhchem 은 첫 대괄호가 **위**다.
                if let (text, len) = readBracket(chars, at: i) { above = text; i += len }
                if let (text, len) = readBracket(chars, at: i) { below = text; i += len }
                out += arrow.latex(above: above, below: below)
                previousWasFormulaUnit = false
                continue
            }

            // 2) 상태 표시 (aq) (s) (l) (g) — 정립으로 쓴다.
            if c == "(", let (state, length) = matchState(chars, at: i) {
                out += "\\text{(\(state))}"
                i += length
                previousWasFormulaUnit = true
                continue
            }

            switch c {
            case " ":
                i += 1
                previousWasFormulaUnit = false

            case "+":
                // mhchem 은 공백으로 가른다 — `H+` 는 **전하**(H⁺)고 `A + B` 는 구분자다.
                // 실제 교재 표기 `\ce{H3PO4 <=> H2PO4^- + H+}` 에서 둘이 한 줄에 같이 나온다.
                if previousWasFormulaUnit && i > 0 && chars[i - 1] != " " {
                    out += "^{+}"
                } else {
                    out += " + "
                    previousWasFormulaUnit = false
                }
                i += 1

            case "*", "·":
                out += " \\cdot "     // 수화물: CuSO4*5H2O
                i += 1
                previousWasFormulaUnit = false

            case "^":
                // 홀로 선 `^` 는 기체 발생 표시다(`\ce{H2 ^}`). 뒤에 전하가 오면 위첨자.
                if isStandalone(chars, at: i) {
                    out += "\\uparrow "
                    i += 1
                    previousWasFormulaUnit = false
                    continue
                }
                i += 1
                let (body, length) = readScriptArgument(chars, at: i)
                i += length
                out += "^{\(chemScript(body))}"

            case "_":
                i += 1
                let (body, length) = readScriptArgument(chars, at: i)
                i += length
                out += "_{\(body)}"

            case "$":
                // $…$ 안은 그대로 수식이다.
                i += 1
                var math = ""
                while i < chars.count && chars[i] != "$" { math.append(chars[i]); i += 1 }
                if i < chars.count { i += 1 }
                out += math
                previousWasFormulaUnit = true

            case "(", ")", "[", "]":
                out += String(c)
                i += 1
                previousWasFormulaUnit = (c == ")" || c == "]")

            case "-", "=", "#":
                // 원자 사이의 결합선. 홑·겹·삼중 결합.
                //
                // **정립 텍스트로 낸다.** 그냥 `=` 로 두면 관계연산자가 되어 양쪽에 5mu 씩
                // 붙는데, 결합선은 원자에 바짝 붙어야 한다(실측: `\ce{CH2=CH2}` 가
                // `CH₂ = CH₂` 로 벌어졌다).
                out += c == "-" ? "\\text{–}"
                     : (c == "=" ? "\\mathord{=}" : "\\mathord{\u{2261}}")
                i += 1
                previousWasFormulaUnit = true

            default:
                if c.isNumber {
                    var digits = ""
                    while i < chars.count && (chars[i].isNumber || chars[i] == ".") {
                        digits.append(chars[i]); i += 1
                    }
                    // 화학식 뒤면 아래첨자, 아니면 계수다.
                    out += previousWasFormulaUnit ? "_{\(digits)}" : digits
                } else if c == "v" && isStandalone(chars, at: i) {
                    // 홀로 선 `v` 는 침전 표시다(`\ce{AgCl v}`).
                    out += "\\downarrow "
                    i += 1
                    previousWasFormulaUnit = false
                } else if c.isLetter {
                    // 원소 기호: 대문자 하나 + 이어지는 소문자들. 소문자로 시작하면
                    // 한 글자씩 끊는다(변수처럼 쓰인 경우).
                    var symbol = String(c)
                    i += 1
                    if c.isUppercase {
                        while i < chars.count && chars[i].isLowercase {
                            symbol.append(chars[i]); i += 1
                        }
                    }
                    out += "\\text{\(symbol)}"
                    previousWasFormulaUnit = true
                } else {
                    // 모르는 글자는 그대로 흘린다.
                    out += String(c)
                    i += 1
                }
            }
        }
        return out
    }

    // MARK: 화살표

    private enum Arrow {
        case right, left, leftRight, equilibrium, equilibriumRight, equilibriumLeft

        func latex(above: String, below: String) -> String {
            let hasLabel = !above.isEmpty || !below.isEmpty
            let command: String
            switch self {
            case .right:            command = hasLabel ? "\\xrightarrow" : "\\longrightarrow"
            case .left:             command = hasLabel ? "\\xleftarrow" : "\\longleftarrow"
            case .leftRight:        command = hasLabel ? "\\xleftrightarrow" : "\\longleftrightarrow"
            // 평형 화살표는 늘어나는 판이 없으니 라벨이 있어도 기호 위에 얹는다.
            case .equilibrium:      command = "\\rightleftharpoons"
            case .equilibriumRight: command = "\\rightleftharpoons"
            case .equilibriumLeft:  command = "\\rightleftharpoons"
            }
            guard hasLabel else { return " \(command) " }
            if command.hasPrefix("\\x") {
                let belowPart = below.isEmpty ? "" : "[\\text{\(below)}]"
                return " \(command)\(belowPart){\\text{\(above)}} "
            }
            // 늘어나지 않는 화살표는 \overset 으로 라벨을 얹는다.
            var result = command
            if !below.isEmpty { result = "\\underset{\\text{\(below)}}{\(result)}" }
            if !above.isEmpty { result = "\\overset{\\text{\(above)}}{\(result)}" }
            return " \(result) "
        }
    }

    private static let arrowTokens: [(String, Arrow)] = [
        ("<=>>", .equilibriumRight), ("<<=>", .equilibriumLeft),
        ("<=>", .equilibrium), ("<->", .leftRight), ("->", .right),
        ("<-", .left), ("=>", .right), ("<=", .left),
    ]

    private static func matchArrow(_ chars: [Character], at index: Int) -> (Arrow, Int)? {
        for (token, arrow) in arrowTokens {
            let end = index + token.count
            guard end <= chars.count else { continue }
            if String(chars[index..<end]) == token { return (arrow, token.count) }
        }
        return nil
    }

    private static let states = ["aq", "s", "l", "g", "cr", "am"]

    private static func matchState(_ chars: [Character], at index: Int) -> (String, Int)? {
        for state in states {
            let token = "(\(state))"
            let end = index + token.count
            guard end <= chars.count else { continue }
            if String(chars[index..<end]) == token { return (state, token.count) }
        }
        return nil
    }

    private static func readBracket(_ chars: [Character], at index: Int) -> (String, Int)? {
        guard index < chars.count, chars[index] == "[" else { return nil }
        var i = index + 1
        var text = ""
        var depth = 1
        while i < chars.count {
            if chars[i] == "[" { depth += 1 }
            if chars[i] == "]" { depth -= 1; if depth == 0 { break } }
            text.append(chars[i]); i += 1
        }
        guard i < chars.count else { return nil }   // 닫히지 않았으면 대괄호가 아니다
        return (text, i - index + 1)
    }

    /// `^` `_` 뒤의 인자. `{…}` 이면 그 안, 아니면 짧게 한 덩이만 먹는다.
    private static func readScriptArgument(_ chars: [Character], at index: Int) -> (String, Int) {
        guard index < chars.count else { return ("", 0) }
        if chars[index] == "{" {
            var i = index + 1
            var text = ""
            var depth = 1
            while i < chars.count {
                if chars[i] == "{" { depth += 1 }
                if chars[i] == "}" { depth -= 1; if depth == 0 { break } }
                text.append(chars[i]); i += 1
            }
            return (text, min(i + 1, chars.count) - index)
        }
        // 전하 표기: 숫자 몇 자 + 부호 하나(2+, 3-, +, -)
        var i = index
        var text = ""
        while i < chars.count && chars[i].isNumber { text.append(chars[i]); i += 1 }
        if i < chars.count && (chars[i] == "+" || chars[i] == "-") {
            text.append(chars[i]); i += 1
        } else if text.isEmpty && i < chars.count {
            text.append(chars[i]); i += 1
        }
        return (text, i - index)
    }

    /// 앞뒤가 공백(또는 끝)이라 홀로 선 글자인가. 침전 `v`·기체 `^` 를 가리는 데 쓴다.
    private static func isStandalone(_ chars: [Character], at index: Int) -> Bool {
        let beforeIsBoundary = index == 0 || chars[index - 1] == " "
        let afterIsBoundary = index + 1 >= chars.count || chars[index + 1] == " "
        return beforeIsBoundary && afterIsBoundary
    }

    /// 전하의 빼기 기호는 하이픈이 아니라 마이너스여야 한다.
    private static func chemScript(_ body: String) -> String {
        body.replacingOccurrences(of: "-", with: "\u{2212}")
    }
}

// MARK: - siunitx

enum MTUnitNotation {

    /// `\SI{값}{단위}` → `값\,단위`. 값만 또는 단위만 주는 형태도 받는다.
    static func toLatex(value: String?, unit: String?) -> String {
        var parts = [String]()
        if let value, !value.isEmpty { parts.append(number(value)) }
        if let unit, !unit.isEmpty { parts.append(units(unit)) }
        return parts.joined(separator: "\\,")
    }

    /// `1.5e3` → `1.5 \times 10^{3}`. 지수 표기가 없으면 그대로.
    static func number(_ source: String) -> String {
        let trimmed = source.trimmingCharacters(in: .whitespaces)
        for separator in ["e", "E", "d", "D"] {
            let pieces = trimmed.components(separatedBy: separator)
            guard pieces.count == 2,
                  !pieces[0].isEmpty,
                  pieces[0].allSatisfy({ $0.isNumber || $0 == "." || $0 == "-" || $0 == "+" }),
                  !pieces[1].isEmpty,
                  pieces[1].allSatisfy({ $0.isNumber || $0 == "-" || $0 == "+" })
            else { continue }
            let exponent = pieces[1].replacingOccurrences(of: "-", with: "\u{2212}")
            return "\(pieces[0]) \\times 10^{\(exponent)}"
        }
        // 구간 표기(`1..2`)나 오차(`1(2)`)는 그대로 둔다.
        return trimmed.replacingOccurrences(of: "-", with: "\u{2212}")
    }

    /// `\kilo\meter\per\second\squared` → `km/s^{2}`
    static func units(_ source: String) -> String {
        var out = ""
        var pendingPer = false
        for token in tokenize(source) {
            switch token {
            case .literal(let text):
                // `\si{km}` 처럼 기호를 직접 쓴 경우. 정립으로 그대로 옮긴다.
                if pendingPer { out += "/"; pendingPer = false }
                out += "\\text{\(text)}"
            case .macro(let name):
                if name == "per" { pendingPer = true; continue }
                if let power = powers[name] { out += "^{\(power)}"; continue }
                guard let symbol = prefixes[name] ?? unitSymbols[name] else {
                    // 모르는 매크로는 이름을 그대로 보여 준다 — 사라지는 것보다 낫다.
                    if !name.isEmpty { out += "\\text{\(name)}" }
                    continue
                }
                if pendingPer { out += "/"; pendingPer = false }
                out += "\\text{\(symbol)}"
            }
        }
        return out
    }

    private enum UnitToken {
        case macro(String)     // `\kilo` 같은 매크로 이름
        case literal(String)   // 매크로가 아닌 글자 뭉치
    }

    /// `\kilo\meter` 처럼 붙어 있는 매크로 이름들을 끊는다.
    private static func tokenize(_ source: String) -> [UnitToken] {
        var tokens = [UnitToken]()
        let chars = Array(source)
        var i = 0
        var literal = ""
        func flush() {
            if !literal.isEmpty { tokens.append(.literal(literal)); literal = "" }
        }
        while i < chars.count {
            if chars[i] == "\\" {
                flush()
                i += 1
                var name = ""
                while i < chars.count && chars[i].isLetter { name.append(chars[i]); i += 1 }
                tokens.append(.macro(name))
            } else if chars[i] == "." || chars[i] == "~" || chars[i] == " " {
                flush()
                i += 1     // 단위 구분자는 버린다(우리는 붙여 쓴다)
            } else {
                literal.append(chars[i]); i += 1
            }
        }
        flush()
        return tokens
    }

    private static let powers: [String: String] = [
        "squared": "2", "cubed": "3", "tothe": "n", "raiseto": "n",
    ]

    private static let prefixes: [String: String] = [
        "yocto": "y", "zepto": "z", "atto": "a", "femto": "f", "pico": "p",
        "nano": "n", "micro": "\u{00B5}", "milli": "m", "centi": "c", "deci": "d",
        "deca": "da", "hecto": "h", "kilo": "k", "mega": "M", "giga": "G",
        "tera": "T", "peta": "P", "exa": "E", "zetta": "Z", "yotta": "Y",
    ]

    private static let unitSymbols: [String: String] = [
        // SI 기본
        "meter": "m", "metre": "m", "second": "s", "kilogram": "kg", "gram": "g",
        "mole": "mol", "kelvin": "K", "ampere": "A", "candela": "cd",
        // SI 유도
        "newton": "N", "joule": "J", "watt": "W", "volt": "V", "ohm": "\u{03A9}",
        "pascal": "Pa", "hertz": "Hz", "coulomb": "C", "farad": "F", "tesla": "T",
        "henry": "H", "weber": "Wb", "siemens": "S", "becquerel": "Bq",
        "gray": "Gy", "sievert": "Sv", "lumen": "lm", "lux": "lx", "katal": "kat",
        "radian": "rad", "steradian": "sr",
        // 병용 단위
        "liter": "L", "litre": "L", "celsius": "\u{2103}", "degree": "\u{00B0}",
        "percent": "%", "electronvolt": "eV", "angstrom": "\u{00C5}",
        "bar": "bar", "atm": "atm", "minute": "min", "hour": "h", "day": "d",
        "year": "a", "tonne": "t", "dalton": "Da", "astronomicalunit": "au",
        "arcminute": "\u{2032}", "arcsecond": "\u{2033}", "neper": "Np", "bel": "B",
    ]
}
