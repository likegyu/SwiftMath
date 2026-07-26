//
//  Created by Mike Griebling on 2022-12-31.
//  Translated from an Objective-C implementation by Kostub Deshmukh.
//
//  This software may be modified and distributed under the terms of the
//  MIT license. See the LICENSE file for details.
//

import Foundation

/** `MTMathListBuilder` is a class for parsing LaTeX into an `MTMathList` that
 can be rendered and processed mathematically.
 */
struct MTEnvProperties {
    var envName: String?
    var ended: Bool
    var numRows: Int
    var alignment: MTColumnAlignment?  // Optional alignment for starred matrix environments
    /// `\begin{array}{lcr}` 처럼 열마다 따로 지정된 정렬.
    var columnAlignments: [MTColumnAlignment]?

    init(name: String?, alignment: MTColumnAlignment? = nil,
         columnAlignments: [MTColumnAlignment]? = nil) {
        self.envName = name
        self.columnAlignments = columnAlignments
        self.numRows = 0
        self.ended = false
        self.alignment = alignment
    }
}

/**
 The error encountered when parsing a LaTeX string.
 
 The `code` in the `NSError` is one of the following indicating why the LaTeX string
 could not be parsed.
 */
enum MTParseErrors:Int {
    /// The braces { } do not match.
    case mismatchBraces = 1
    /// A command in the string is not recognized.
    case invalidCommand
    /// An expected character such as ] was not found.
    case characterNotFound
    /// The \left or \right command was not followed by a delimiter.
    case missingDelimiter
    /// The delimiter following \left or \right was not a valid delimiter.
    case invalidDelimiter
    /// There is no \right corresponding to the \left command.
    case missingRight
    /// There is no \left corresponding to the \right command.
    case missingLeft
    /// The environment given to the \begin command is not recognized
    case invalidEnv
    /// A command is used which is only valid inside a \begin,\end environment
    case missingEnv
    /// There is no \begin corresponding to the \end command.
    case missingBegin
    /// There is no \end corresponding to the \begin command.
    case missingEnd
    /// The number of columns do not match the environment
    case invalidNumColumns
    /// Internal error, due to a programming mistake.
    case internalError
    /// Limit control applied incorrectly
    case invalidLimits
    /// The expression nests deeper than the parser will follow.
    case nestingTooDeep
}

let MTParseError = "ParseError"

/** `MTMathListBuilder` is a class for parsing LaTeX into an `MTMathList` that
 can be rendered and processed mathematically.
 */
public struct MTMathListBuilder {
    /// The math mode determines rendering style (inline vs display)
    enum MathMode {
        /// Display style - larger operators, limits above/below (e.g., $$...$$, \[...\])
        case display
        /// Inline/text style - compact operators, limits to the side (e.g., $...$, \(...\))
        case inline

        /// Convert MathMode to MTLineStyle for rendering
        func toLineStyle() -> MTLineStyle {
            switch self {
            case .display:
                return .display
            case .inline:
                return .text
            }
        }
    }

    var string: String
    var currentCharIndex: String.Index
    var currentInnerAtom: MTInner?
    var currentEnv: MTEnvProperties?
    var currentFontStyle:MTFontStyle
    var spacesAllowed:Bool

    /// 현재 재귀 깊이. buildInternal 이 중첩 그룹마다 자기를 다시 부르므로 이 값이 곧
    /// 스택 사용량에 비례한다.
    var nestingDepth = 0

    /// 파서가 따라 들어갈 최대 중첩 깊이.
    ///
    /// 스택 오버플로는 Swift 의 오류 처리로 **잡을 수 없다** — 프로세스가 즉사한다.
    /// 실측(iOS 스택 크기 재현): 메인 스레드 1MB 에서 약 700중첩, 백그라운드 512KB 에서
    /// 약 400중첩에 죽었다. 신뢰할 수 없는 입력(LLM 생성 LaTeX)을 렌더하는 이상, 크래시를
    /// 평범한 파싱 오류로 강등시켜야 호출부의 원문 폴백이 받아낼 수 있다.
    ///
    /// 100 인 이유: 사람이 쓰는 수식은 깊어야 20~30단이고(3단 중첩 분수가 15단 안팎),
    /// 실측 한계의 1/4 이라 어떤 스레드에서도 안전하다. 필요하면 소비자가 올릴 수 있다.
    public static var maxNestingDepth = 100
    var mathMode: MathMode = .display

    /** Contains any error that occurred during parsing. */
    var error:NSError?
    
    // MARK: - Character-handling routines
    
    var hasCharacters: Bool { currentCharIndex < string.endIndex }
    
    // gets the next character and increments the index
    mutating func getNextCharacter() -> Character {
        assert(self.hasCharacters, "Retrieving character at index \(self.currentCharIndex) beyond length \(self.string.count)")
        let ch = string[currentCharIndex]
        currentCharIndex = string.index(after: currentCharIndex)
        return ch
    }
    
    mutating func unlookCharacter() {
        assert(currentCharIndex > string.startIndex, "Unlooking when at the first character.")
        if currentCharIndex > string.startIndex {
            currentCharIndex = string.index(before: currentCharIndex)
        }
    }

    // Peek at next command without consuming it (for \not lookahead)
    mutating func peekNextCommand() -> String {
        let savedIndex = currentCharIndex
        skipSpaces()

        guard hasCharacters else {
            currentCharIndex = savedIndex
            return ""
        }

        let char = getNextCharacter()
        let command: String

        if char == "\\" {
            command = readCommand()
        } else {
            command = ""
        }

        // Restore position
        currentCharIndex = savedIndex
        return command
    }

    // Consume the next command (after peeking)
    mutating func consumeNextCommand() {
        skipSpaces()

        guard hasCharacters else { return }

        let char = getNextCharacter()
        if char == "\\" {
            _ = readCommand()
        }
    }


    
    mutating func expectCharacter(_ ch: Character) -> Bool {
        MTAssertNotSpace(ch)
        self.skipSpaces()
        
        if self.hasCharacters {
            let nextChar = self.getNextCharacter()
            MTAssertNotSpace(nextChar)
            if nextChar == ch {
                return true
            } else {
                self.unlookCharacter()
                return false
            }
        }
        return false
    }
    
    public static let spaceToCommands: [CGFloat: String] = [
        3 : ",",
        4 : ">",
        5 : ";",
        (-3) : "!",
        18 : "quad",
        36 : "qquad",
    ]
    
    public static let styleToCommands: [MTLineStyle: String] = [
        .display: "displaystyle",
        .text: "textstyle",
        .script: "scriptstyle",
        .scriptOfScript: "scriptscriptstyle"
    ]

    // Comprehensive mapping of \not command combinations to Unicode negated symbols
    public static let notCombinations: [String: String] = [
        // Primary targets (user requested)
        "equiv": "\u{2262}",    // ≢ Not equivalent
        "subset": "\u{2284}",   // ⊄ Not subset
        "in": "\u{2209}",       // ∉ Not element of

        // Additional standard negations
        "sim": "\u{2241}",      // ≁ Not similar
        "approx": "\u{2249}",   // ≉ Not approximately equal
        "cong": "\u{2247}",     // ≇ Not congruent
        "parallel": "\u{2226}", // ∦ Not parallel
        "subseteq": "\u{2288}", // ⊈ Not subset or equal
        "supset": "\u{2285}",   // ⊅ Not superset
        "supseteq": "\u{2289}", // ⊉ Not superset or equal
        "=": "\u{2260}",        // ≠ Not equal (alternative to \neq)
    ]

    /// Delimiter sizing commands with their size multipliers (relative to font size).
    /// Values based on standard TeX: at 10pt, \big=8.5pt, \Big=11.5pt, \bigg=14.5pt, \Bigg=17.5pt
    /// These translate to approximately 0.85x, 1.15x, 1.45x, 1.75x of font size.
    /// We use slightly larger values to ensure visible size differences.
    public static let delimiterSizeCommands: [String: CGFloat] = [
        // Basic sizing commands
        "big": 1.0,
        "Big": 1.4,
        "bigg": 1.8,
        "Bigg": 2.2,
        // Left variants (same sizes, just semantic distinction in LaTeX)
        "bigl": 1.0,
        "Bigl": 1.4,
        "biggl": 1.8,
        "Biggl": 2.2,
        // Right variants
        "bigr": 1.0,
        "Bigr": 1.4,
        "biggr": 1.8,
        "Biggr": 2.2,
        // Middle variants (used between delimiters)
        "bigm": 1.0,
        "Bigm": 1.4,
        "biggm": 1.8,
        "Biggm": 2.2,
    ]

    init(string: String) {
        self.error = nil
        self.string = string
        self.currentCharIndex = string.startIndex
        self.currentFontStyle = .defaultStyle
        self.spacesAllowed = false
    }

    // MARK: - Delimiter Detection

    /// Detects and strips LaTeX math delimiters from the input string.
    /// Returns the cleaned content and the detected math mode.
    /// Supports: $...$ \(...\) $$...$$ \[...\] and environments
    func detectAndStripDelimiters(from str: String) -> (String, MathMode) {
        let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check display delimiters first (more specific patterns)

        // \[...\] - LaTeX display math
        if trimmed.hasPrefix("\\[") && trimmed.hasSuffix("\\]") && trimmed.count > 4 {
            let content = String(trimmed.dropFirst(2).dropLast(2))
            return (content, .display)
        }

        // $$...$$ - TeX display math (check before single $)
        if trimmed.hasPrefix("$$") && trimmed.hasSuffix("$$") && trimmed.count > 4 {
            let content = String(trimmed.dropFirst(2).dropLast(2))
            return (content, .display)
        }

        // Check inline delimiters

        // \(...\) - LaTeX inline math
        if trimmed.hasPrefix("\\(") && trimmed.hasSuffix("\\)") && trimmed.count > 4 {
            let content = String(trimmed.dropFirst(2).dropLast(2))
            return (content, .inline)
        }

        // $...$ - TeX inline math (must check after $$)
        if trimmed.hasPrefix("$") && trimmed.hasSuffix("$") && trimmed.count > 2 && !trimmed.hasPrefix("$$") {
            let content = String(trimmed.dropFirst(1).dropLast(1))
            return (content, .inline)
        }

        // Check if it's an environment (\begin{...}\end{...})
        // These are handled by existing logic and are display mode by default
        if trimmed.hasPrefix("\\begin{") {
            return (str, .display)
        }

        // No delimiters found - default to display mode (current behavior for backward compatibility)
        return (str, .display)
    }

    // MARK: - MTMathList builder functions

    /// Builds a mathlist from the internal `string`. Returns nil if there is an error.
    public mutating func build() -> MTMathList? {
        // Detect and strip delimiters, updating the string and mode
        let (cleanedString, mode) = detectAndStripDelimiters(from: self.string)
        self.string = cleanedString
        self.currentCharIndex = cleanedString.startIndex
        self.mathMode = mode

        // If inline mode, we could optionally prepend a \textstyle command
        // to force inline rendering of operators. For now, just track the mode.

        let list = self.buildInternal(false)
        if self.hasCharacters && error == nil {
            self.setError(.mismatchBraces, message: "Mismatched braces: \(self.string)")
            return nil
        }
        if error != nil {
            return nil
        }

        // Note: For inline mode, we insert \textstyle to match LaTeX behavior.
        // However, fractionStyle() has been modified to keep fractions at the
        // same font size in both display and text modes (not one level smaller).
        // Large operators show limits above/below in text style due to the updated
        // condition in makeLargeOp() that checks both .display and .text styles.
        if mode == .inline && list != nil && !list!.atoms.isEmpty {
            // Prepend \textstyle to force inline rendering
            let styleAtom = MTMathStyle(style: .text)
            list!.atoms.insert(styleAtom, at: 0)
        }

        return list
    }
    
    /** Construct a math list from a given string. If there is parse error, returns
     nil. To retrieve the error use the function `MTMathListBuilder.build(fromString:error:)`.
     */
    public static func build(fromString string: String) -> MTMathList? {
        var builder = MTMathListBuilder(string: string)
        return builder.build()
    }
    
    /** Construct a math list from a given string. If there is an error while
     constructing the string, this returns nil. The error is returned in the
     `error` parameter.
     */
    public static func build(fromString string: String, error:inout NSError?) -> MTMathList? {
        var builder = MTMathListBuilder(string: string)
        let output = builder.build()
        if builder.error != nil {
            error = builder.error
            return nil
        }
        return output
    }

    /** Construct a math list from a given string and return the detected style.
     This method detects LaTeX delimiters like \[...\], $$...$$, $...$, \(...\)
     and returns the appropriate rendering style (.display or .text).

     If there is a parse error, returns nil for the MathList.

     - Parameter string: The LaTeX string to parse
     - Returns: A tuple containing the parsed MathList and the detected MTLineStyle
     */
    public static func buildWithStyle(fromString string: String) -> (mathList: MTMathList?, style: MTLineStyle) {
        var builder = MTMathListBuilder(string: string)
        let mathList = builder.build()
        let style = builder.mathMode.toLineStyle()
        return (mathList, style)
    }

    /** Construct a math list from a given string and return the detected style.
     This method detects LaTeX delimiters like \[...\], $$...$$, $...$, \(...\)
     and returns the appropriate rendering style (.display or .text).

     If there is an error while constructing the string, this returns nil for the MathList.
     The error is returned in the `error` parameter.

     - Parameters:
        - string: The LaTeX string to parse
        - error: An inout parameter that will contain any parse error
     - Returns: A tuple containing the parsed MathList and the detected MTLineStyle
     */
    public static func buildWithStyle(fromString string: String, error: inout NSError?) -> (mathList: MTMathList?, style: MTLineStyle) {
        var builder = MTMathListBuilder(string: string)
        let output = builder.build()
        let style = builder.mathMode.toLineStyle()
        if builder.error != nil {
            error = builder.error
            return (nil, style)
        }
        return (output, style)
    }
    
    public mutating func buildInternal(_ oneCharOnly: Bool) -> MTMathList? {
        self.buildInternal(oneCharOnly, stopChar: nil)
    }
    
    public mutating func buildInternal(_ oneCharOnly: Bool, stopChar stop: Character?) -> MTMathList? {
        // 중첩이 스택을 먹어치우기 전에 멈춘다. 여기서 막지 못하면 스택 오버플로가 나는데,
        // 그건 잡을 수 있는 오류가 아니라 프로세스 즉사라서 호출부가 손쓸 방법이 없다.
        nestingDepth += 1
        defer { nestingDepth -= 1 }
        if nestingDepth > Self.maxNestingDepth {
            self.setError(.nestingTooDeep,
                          message: "Nesting too deep (limit \(Self.maxNestingDepth))")
            return nil
        }

        let list = MTMathList()
        assert(!(oneCharOnly && stop != nil), "Cannot set both oneCharOnly and stopChar.")
        var prevAtom: MTMathAtom? = nil
        while self.hasCharacters {
            if error != nil { return nil } // If there is an error thus far then bail out.
            
            var atom: MTMathAtom? = nil
            let char = self.getNextCharacter()
            
            if oneCharOnly {
                if char == "^" || char == "}" || char == "_" || char == "&" {
                    // this is not the character we are looking for.
                    // They are meant for the caller to look at.
                    self.unlookCharacter()
                    return list
                }
            }
            // If there is a stop character, keep scanning 'til we find it
            if stop != nil && char == stop! {
                return list
            }
            
            if char == "^" {
                assert(!oneCharOnly, "This should have been handled before")
                if (prevAtom == nil || prevAtom!.superScript != nil || !prevAtom!.isScriptAllowed()) {
                    // If there is no previous atom, or if it already has a superscript
                    // or if scripts are not allowed for it, then add an empty node.
                    prevAtom = MTMathAtom(type: .ordinary, value: "")
                    list.add(prevAtom!)
                }
                // this is a superscript for the previous atom
                // note: if the next char is the stopChar it will be consumed by the ^ and so it doesn't count as stop
                prevAtom!.superScript = self.buildInternal(true)
                continue
            } else if char == "_" {
                assert(!oneCharOnly, "This should have been handled before")
                if (prevAtom == nil || prevAtom!.subScript != nil || !prevAtom!.isScriptAllowed()) {
                    // If there is no previous atom, or if it already has a subcript
                    // or if scripts are not allowed for it, then add an empty node.
                    prevAtom = MTMathAtom(type: .ordinary, value: "")
                    list.add(prevAtom!)
                }
                // this is a subscript for the previous atom
                // note: if the next char is the stopChar it will be consumed by the _ and so it doesn't count as stop
                prevAtom!.subScript = self.buildInternal(true)
                continue
            } else if char == "{" {
                // this puts us in a recursive routine, and sets oneCharOnly to false and no stop character
                if let subList = self.buildInternal(false, stopChar: "}") {
                    prevAtom = subList.atoms.last
                    list.append(subList)
                    if oneCharOnly {
                        return list
                    }
                }
                continue
            } else if char == "}" {
                // \ means a command
                assert(!oneCharOnly, "This should have been handled before")
                assert(stop == nil, "This should have been handled before")
                // Special case: } terminates implicit table (envName == nil) created by \\
                // This happens when \\ is used inside braces: \substack{a \\ b}
                if self.currentEnv != nil && self.currentEnv!.envName == nil {
                    // Mark environment as ended, don't consume the }
                    self.currentEnv!.ended = true
                    return list
                }
                // We encountered a closing brace when there is no stop set, that means there was no
                // corresponding opening brace.
                self.setError(.mismatchBraces, message:"Mismatched braces.")
                return nil
            } else if char == "\\" {
                let command = readCommand()
                let done = stopCommand(command, list:list, stopChar:stop)
                if done != nil {
                    return done
                } else if error != nil {
                    return nil
                }
                if self.applyModifier(command, atom:prevAtom) {
                    continue
                }
                
                // \ce·\SI 는 별도 문법이라 원문을 통째로 받아 LaTeX 로 옮긴 뒤 다시 파싱한다.
                // 원자 하나가 아니라 리스트가 나오므로 여기서 바로 이어 붙인다.
                if let sublist = self.expandScienceNotation(command) {
                    prevAtom = sublist.atoms.last
                    list.append(sublist)
                    if oneCharOnly { return list }
                    continue
                }

                if let fontStyle = MTMathAtomFactory.fontStyleWithName(command) {
                    let oldSpacesAllowed = spacesAllowed
                    // Text has special consideration where it allows spaces without escaping.
                    spacesAllowed = command == "text"
                    let oldFontStyle = currentFontStyle
                    currentFontStyle = fontStyle
                    if let sublist = self.buildInternal(true) {
                        // Restore the font style.
                        currentFontStyle = oldFontStyle
                        spacesAllowed = oldSpacesAllowed
                        
                        prevAtom = sublist.atoms.last
                        list.append(sublist)
                        if oneCharOnly {
                            return list
                        }
                    }
                    continue
                }
                atom = self.atomForCommand(command)
                if atom == nil {
                    // this was an unknown command,
                    // we flag an error and return
                    // (note setError will not set the error if there is already one, so we flag internal error
                    // in the odd case that an _error is not set.
                    self.setError(.internalError, message:"Internal error")
                    return nil
                }
            } else if char == "&" {
                // used for column separation in tables
                assert(!oneCharOnly, "This should have been handled before")
                if self.currentEnv != nil {
                    return list
                } else {
                    // Create a new table with the current list and a default env
                    if let table = self.buildTable(env: nil, firstList: list, isRow: false) {
                        return MTMathList(atom: table)
                    } else {
                        return nil
                    }
                }
            } else if spacesAllowed && char == " " {
                // If spaces are allowed then spaces do not need escaping with a \ before being used.
                atom = MTMathAtomFactory.atom(forLatexSymbol: " ")
            } else {
                atom = MTMathAtomFactory.atom(forCharacter: char)
                if atom == nil {
                    // Not a recognized character in standard math mode
                    // In text mode (spacesAllowed && roman style), accept any Unicode character for fallback font support
                    // This enables Chinese, Japanese, Korean, emoji, etc. in \text{} commands
                    if spacesAllowed && currentFontStyle == .roman {
                        atom = MTMathAtom(type: .ordinary, value: String(char))
                    } else if char.utf32Char > 0x007E {
                        // Non-ASCII in *math* mode (outside \text{}): also accept as an ordinary
                        // atom rather than dropping it.
                        //
                        // Silently discarding these is worse than rendering them imperfectly:
                        // "속도 = 5" used to typeset as "=5" and "v_{초기}" as "v_{}" — the content
                        // vanished with no error, so neither the user nor the caller could tell.
                        // Real-world input (LLM-generated study notes in Korean/Japanese/Chinese)
                        // routinely puts CJK inside math spans and subscripts, where authors are
                        // unlikely to wrap every run in \text{}.
                        //
                        // The glyphs come from the fallback-font path added for \text{} (see
                        // MTTypesetter), so they render the same way here. Control characters and
                        // ASCII with LaTeX meaning ($ % # & ~ ' ^ _ { } \) are unaffected: they are
                        // handled above or below and never reach this branch.
                        atom = MTMathAtom(type: .ordinary, value: String(char))
                    } else {
                        // In math mode or non-text commands, skip unrecognized characters
                        continue
                    }
                }
            }
            
            assert(atom != nil, "Atom shouldn't be nil")
            atom?.fontStyle = currentFontStyle
            // If this is an accent atom (e.g., from an accented character like "é"),
            // propagate the font style to the inner list atoms that don't already have
            // an explicit font style. This handles Unicode accented characters which are
            // converted to accents by atom(fromAccentedCharacter:) without font style context.
            // We only set font style on atoms with .defaultStyle to avoid overriding
            // explicit font style commands like \textbf inside accents.
            if let accent = atom as? MTAccent, let innerList = accent.innerList {
                for innerAtom in innerList.atoms {
                    if innerAtom.fontStyle == .defaultStyle {
                        innerAtom.fontStyle = currentFontStyle
                    }
                }
            }
            list.add(atom)
            prevAtom = atom
            
            if oneCharOnly {
                return list
            }
        }
        if stop != nil {
            if stop == "}" {
                // We did not find a corresponding closing brace.
                self.setError(.mismatchBraces, message:"Missing closing brace")
            } else {
                // we never found our stop character
                let errorMessage = "Expected character not found: \(stop!)"
                self.setError(.characterNotFound, message:errorMessage)
            }
        }
        return list
    }
    
    
    // MARK: - MTMathList to LaTeX conversion
    
    /// This converts the MTMathList to LaTeX.
    public static func mathListToString(_ ml: MTMathList?) -> String {
        var str = ""
        var currentfontStyle = MTFontStyle.defaultStyle
        if let atomList = ml {
            for atom in atomList.atoms {
                if currentfontStyle != atom.fontStyle {
                    if currentfontStyle != .defaultStyle {
                        str += "}"
                    }
                    if atom.fontStyle != .defaultStyle {
                        let fontStyleName = MTMathAtomFactory.fontNameForStyle(atom.fontStyle)
                        str += "\\\(fontStyleName){"
                    }
                    currentfontStyle = atom.fontStyle
                }
                if atom.type == .fraction {
                    if let frac = atom as? MTFraction {
                        if frac.isContinuedFraction {
                            // Generate \cfrac with optional alignment
                            if frac.alignment != "c" {
                                str += "\\cfrac[\(frac.alignment)]{\(mathListToString(frac.numerator!))}{\(mathListToString(frac.denominator!))}"
                            } else {
                                str += "\\cfrac{\(mathListToString(frac.numerator!))}{\(mathListToString(frac.denominator!))}"
                            }
                        } else if frac.hasRule {
                            str += "\\frac{\(mathListToString(frac.numerator!))}{\(mathListToString(frac.denominator!))}"
                        } else {
                            let command: String
                            if frac.leftDelimiter.isEmpty && frac.rightDelimiter.isEmpty {
                                command = "atop"
                            } else if frac.leftDelimiter == "(" && frac.rightDelimiter == ")" {
                                command = "choose"
                            } else if frac.leftDelimiter == "{" && frac.rightDelimiter == "}" {
                                command = "brace"
                            } else if frac.leftDelimiter == "[" && frac.rightDelimiter == "]" {
                                command = "brack"
                            } else {
                                command = "atopwithdelims\(frac.leftDelimiter)\(frac.rightDelimiter)"
                            }
                            str += "{\(mathListToString(frac.numerator!)) \\\(command) \(mathListToString(frac.denominator!))}"
                        }
                    }
                } else if atom.type == .radical {
                    str += "\\sqrt"
                    if let rad = atom as? MTRadical {
                        if rad.degree != nil {
                            str += "[\(mathListToString(rad.degree!))]"
                        }
                        str += "{\(mathListToString(rad.radicand!))}"
                    }
                } else if atom.type == .inner {
                    if let inner = atom as? MTInner {
                        if inner.leftBoundary != nil || inner.rightBoundary != nil {
                            if inner.leftBoundary != nil {
                                str += "\\left\(delimToString(delim: inner.leftBoundary!)) "
                            } else {
                                str += "\\left. "
                            }
                            
                            str += mathListToString(inner.innerList!)
                            
                            if inner.rightBoundary != nil {
                                str += "\\right\(delimToString(delim: inner.rightBoundary!)) "
                            } else {
                                str += "\\right. "
                            }
                        } else {
                            str += "{\(mathListToString(inner.innerList!))}"
                        }
                    }
                } else if atom.type == .table {
                    if let table = atom as? MTMathTable {
                        if !table.environment.isEmpty {
                            str += "\\begin{\(table.environment)}"
                        }
                        
                        for i in 0..<table.numRows {
                            let row = table.cells[i]
                            for j in 0..<row.count {
                                let cell = row[j]
                                if table.environment == "matrix" {
                                    if cell.atoms.count >= 1 && cell.atoms[0].type == .style {
                                        // remove first atom
                                        cell.atoms.removeFirst()
                                    }
                                }
                                if table.environment == "eqalign" || table.environment == "aligned" || table.environment == "split" {
                                    if j == 1 && cell.atoms.count >= 1 && cell.atoms[0].type == .ordinary && cell.atoms[0].nucleus.count == 0 {
                                        // remove empty nucleus added for spacing
                                        cell.atoms.removeFirst()
                                    }
                                }
                                str += mathListToString(cell)
                                if j < row.count - 1 {
                                    str += "&"
                                }
                            }
                            if i < table.numRows - 1 {
                                str += "\\\\ "
                            }
                        }
                        if !table.environment.isEmpty {
                            str += "\\end{\(table.environment)}"
                        }
                    }
                } else if atom.type == .overline {
                    if let overline = atom as? MTOverLine {
                        str += "\\overline"
                        str += "{\(mathListToString(overline.innerList!))}"
                    }
                } else if atom.type == .underline {
                    if let underline = atom as? MTUnderLine {
                        str += "\\underline"
                        str += "{\(mathListToString(underline.innerList!))}"
                    }
                } else if let textColor = atom as? MTMathTextColor {
                    // 색 원자는 되돌리기에 아예 빠져 있었다. nucleus 가 비어 있어 일반 경로가
                    // `{}` 만 뱉었고, 색과 내용이 함께 사라졌다.
                    str += "\\textcolor{\(textColor.colorString)}{\(mathListToString(textColor.innerList ?? MTMathList()))}"
                } else if let colorbox = atom as? MTMathColorbox {
                    str += "\\colorbox{\(colorbox.colorString)}{\(mathListToString(colorbox.innerList ?? MTMathList()))}"
                } else if let color = atom as? MTMathColor {
                    // MTMathTextColor 를 먼저 본다 — 상속 관계가 아니라 형제지만, 순서를
                    // 고정해 두면 나중에 계층이 바뀌어도 의도가 남는다.
                    str += "\\color{\(color.colorString)}{\(mathListToString(color.innerList ?? MTMathList()))}"
                } else if let decorated = atom as? MTDecorated {
                    let name = MTMathListBuilder.decorationKinds
                        .first { $0.value == decorated.kind && $0.key != "fbox" && $0.key != "framebox" }?.key
                    str += "\\\(name ?? "boxed"){\(mathListToString(decorated.innerList ?? MTMathList()))}"
                } else if let underOver = atom as? MTUnderOver {
                    // 타입이 아니라 클래스로 가른다 — \stackrel 은 type 이 .relation 이다.
                    let base = mathListToString(underOver.innerList ?? MTMathList())
                    if let over = underOver.over, underOver.under == nil {
                        str += "\\overset{\(mathListToString(over))}{\(base)}"
                    } else if let under = underOver.under, underOver.over == nil {
                        str += "\\underset{\(mathListToString(under))}{\(base)}"
                    } else if let over = underOver.over, let under = underOver.under {
                        // 둘 다 있으면 한 명령으로는 못 쓴다. 중첩해서 되돌린다.
                        str += "\\underset{\(mathListToString(under))}{\\overset{\(mathListToString(over))}{\(base)}}"
                    } else {
                        str += base
                    }
                } else if atom.type == .accent {
                    if let accent = atom as? MTAccent {
                        str += "\\\(MTMathAtomFactory.accentName(accent)!){\(mathListToString(accent.innerList!))}"
                    }
                } else if atom.type == .largeOperator {
                    let op = atom as! MTLargeOperator
                    let command = MTMathAtomFactory.latexSymbolName(for: atom)
                    let originalOp = MTMathAtomFactory.atom(forLatexSymbol: command!) as! MTLargeOperator
                    str += "\\\(command!) "
                    if originalOp.limits != op.limits {
                        if op.limits {
                            str += "\\limits "
                        } else {
                            str += "\\nolimits "
                        }
                    }
                } else if atom.type == .space {
                    if let space = atom as? MTMathSpace {
                        if let command = Self.spaceToCommands[space.space] {
                            str += "\\\(command) "
                        } else {
                            str += String(format: "\\mkern%.1fmu", space.space)
                        }
                    }
                } else if atom.type == .style {
                    if let style = atom as? MTMathStyle {
                        if let command = Self.styleToCommands[style.style] {
                            str += "\\\(command) "
                        }
                    }
                } else if atom.nucleus.isEmpty {
                    str += "{}"
                } else if atom.nucleus == "\u{2236}" {
                    // math colon
                    str += ":"
                } else if atom.nucleus == "\u{2212}" {
                    // math minus
                    str += "-"
                } else {
                    if let command = MTMathAtomFactory.latexSymbolName(for: atom) {
                        str += "\\\(command) "
                    } else {
                        str += "\(atom.nucleus)"
                    }
                }
                
                if atom.superScript != nil {
                    str += "^{\(mathListToString(atom.superScript!))}"
                }
                
                if atom.subScript != nil {
                    str += "_{\(mathListToString(atom.subScript!))}"
                }
            }
        }
        if currentfontStyle != .defaultStyle {
            str += "}"
        }
        return str
    }
    
    public static func delimToString(delim: MTMathAtom) -> String {
        if let command = MTMathAtomFactory.getDelimiterName(of: delim) {
            let singleChars = [ "(", ")", "[", "]", "<", ">", "|", ".", "/"]
            if singleChars.contains(command) {
                return command
            } else if command == "||" {
                return "\\|"
            } else {
                return "\\\(command)"
            }
        }
        return ""
    }
    
    /// 별표형이 "번호를 안 붙인다"는 뜻뿐인 환경들. 별을 떼고 같은 조판을 쓴다.
    static let numberlessEnvironments: Set<String> = [
        "align", "alignat", "flalign", "equation", "multline", "gather", "gathered", "eqnarray",
    ]

    /// 라벨 폭에 맞춰 늘어나는 화살표들. 화학 반응식(`A \xrightarrow{촉매} B`)에 자주 나온다.
    static let stretchyArrowCommands: [String: MTStretchyArrowDirection] = [
        "xrightarrow": .right, "xleftarrow": .left,
        "xRightarrow": .right, "xLeftarrow": .left,
        "xleftrightarrow": .both, "xLeftrightarrow": .both,
        "xrightleftharpoons": .both, "xhookrightarrow": .right, "xhookleftarrow": .left,
        "xmapsto": .right, "xlongequal": .both,
    ]

    /// 내용 폭에 맞춰 늘어나는 악센트. `isOver` 가 위/아래를 가른다.
    /// `\overrightarrow` 는 이미 MTAccent 로 구현돼 있어 여기 없다.
    static let stretchyAccentGlyphs: [String: (glyph: String, isOver: Bool)] = [
        "underrightarrow": ("\u{2192}", false), "underleftarrow": ("\u{2190}", false),
        "underleftrightarrow": ("\u{2194}", false),
        "underparen": ("\u{23DD}", false),      // BOTTOM PARENTHESIS
        "overparen": ("\u{23DC}", true),        // TOP PARENTHESIS
        "overbracket": ("\u{23B4}", true), "underbracket": ("\u{23B5}", false),
    ]

    /// 내용 위에 선을 덧그리는 명령들. `\fbox` 는 본문용이지만 수식 안에서도 자주 쓰인다.
    static let decorationKinds: [String: MTDecorated.Kind] = [
        "boxed": .boxed, "fbox": .boxed, "framebox": .boxed,
        "cancel": .cancel, "bcancel": .backCancel, "xcancel": .crossCancel,
        "phantom": .phantom, "hphantom": .horizontalPhantom,
        "vphantom": .verticalPhantom, "smash": .smash,
    ]

    mutating func atomForCommand(_ command:String) -> MTMathAtom? {
        if let atom = MTMathAtomFactory.atom(forLatexSymbol: command) {
            return atom
        }
        if let accent = MTMathAtomFactory.accent(withName: command) {
            // The command is an accent
            accent.innerList = self.buildInternal(true)
            return accent;
        } else if command == "frac" {
            // A fraction command has 2 arguments
            let frac = MTFraction()
            frac.numerator = self.buildInternal(true)
            frac.denominator = self.buildInternal(true)
            return frac;
        } else if command == "cfrac" {
            // A continued fraction command with optional alignment and 2 arguments
            let frac = MTFraction()
            frac.isContinuedFraction = true

            // Parse optional alignment parameter [l], [r], [c]
            skipSpaces()
            if hasCharacters && string[currentCharIndex] == "[" {
                _ = getNextCharacter() // consume '['
                if hasCharacters {
                    let alignmentChar = getNextCharacter()
                    if alignmentChar == "l" || alignmentChar == "r" || alignmentChar == "c" {
                        frac.alignment = String(alignmentChar)
                    }
                }
                // Consume closing ']'
                if hasCharacters && string[currentCharIndex] == "]" {
                    _ = getNextCharacter()
                }
            }

            frac.numerator = self.buildInternal(true)
            frac.denominator = self.buildInternal(true)
            return frac;
        } else if command == "dfrac" {
            // Display-style fraction command has 2 arguments
            let frac = MTFraction()
            let numerator = self.buildInternal(true)
            let denominator = self.buildInternal(true)

            // Prepend \displaystyle to force display mode rendering
            let displayStyle = MTMathStyle(style: .display)
            numerator?.insert(displayStyle, at: 0)
            denominator?.insert(displayStyle, at: 0)

            frac.numerator = numerator
            frac.denominator = denominator
            return frac;
        } else if command == "tfrac" {
            // Text-style fraction command has 2 arguments
            let frac = MTFraction()
            let numerator = self.buildInternal(true)
            let denominator = self.buildInternal(true)

            // Prepend \textstyle to force text mode rendering
            let textStyle = MTMathStyle(style: .text)
            numerator?.insert(textStyle, at: 0)
            denominator?.insert(textStyle, at: 0)

            frac.numerator = numerator
            frac.denominator = denominator
            return frac;
        } else if command == "binom" || command == "dbinom" || command == "tbinom" {
            // A binom command has 2 arguments
            // \dbinom·\tbinom 은 스타일만 강제하는 변형이다. 조판 스타일 강제는 아직 없으니
            // 같은 모양으로 그린다 — 표기가 통째로 깨지는 것보다 크기가 조금 다른 게 낫다.
            let frac = MTFraction(hasRule: false)
            frac.numerator = self.buildInternal(true)
            frac.denominator = self.buildInternal(true)
            frac.leftDelimiter = "(";
            frac.rightDelimiter = ")";
            return frac;
        } else if command == "bra" {
            // Dirac bra notation: \bra{psi} -> ⟨psi|
            let inner = MTInner()
            inner.leftBoundary = MTMathAtomFactory.boundary(forDelimiter: "langle")
            inner.rightBoundary = MTMathAtomFactory.boundary(forDelimiter: "|")
            inner.innerList = self.buildInternal(true)
            return inner
        } else if command == "ket" {
            // Dirac ket notation: \ket{psi} -> |psi⟩
            let inner = MTInner()
            inner.leftBoundary = MTMathAtomFactory.boundary(forDelimiter: "|")
            inner.rightBoundary = MTMathAtomFactory.boundary(forDelimiter: "rangle")
            inner.innerList = self.buildInternal(true)
            return inner
        } else if command == "braket" {
            // Dirac braket notation: \braket{phi}{psi} -> ⟨phi|psi⟩
            let inner = MTInner()
            inner.leftBoundary = MTMathAtomFactory.boundary(forDelimiter: "langle")
            inner.rightBoundary = MTMathAtomFactory.boundary(forDelimiter: "rangle")
            // Build the inner content: phi | psi
            let phi = self.buildInternal(true)
            let psi = self.buildInternal(true)
            let content = MTMathList()
            if let phiList = phi {
                for atom in phiList.atoms {
                    content.add(atom)
                }
            }
            // Add the | separator
            content.add(MTMathAtom(type: .ordinary, value: "|"))
            if let psiList = psi {
                for atom in psiList.atoms {
                    content.add(atom)
                }
            }
            inner.innerList = content
            return inner
        } else if command == "operatorname" || command == "operatorname*" {
            // \operatorname{name} creates a custom operator with proper spacing
            // \operatorname*{name} creates an operator with limits above/below
            let hasLimits = command.hasSuffix("*")

            // Parse the operator name
            let content = self.buildInternal(true)

            // Convert the parsed content to a string
            var operatorName = ""
            if let atoms = content?.atoms {
                for atom in atoms {
                    operatorName += atom.nucleus
                }
            }

            if operatorName.isEmpty {
                let errorMessage = "Missing operator name for \\operatorname"
                self.setError(.invalidCommand, message: errorMessage)
                return nil
            }

            return MTLargeOperator(value: operatorName, limits: hasLimits)
        } else if command == "sqrt" {
            // A sqrt command with one argument
            let rad = MTRadical()
            guard self.hasCharacters else {
                rad.radicand = self.buildInternal(true)
                return rad
            }
            let ch = self.getNextCharacter()
            if (ch == "[") {
                // special handling for sqrt[degree]{radicand}
                rad.degree = self.buildInternal(false, stopChar:"]")
                rad.radicand = self.buildInternal(true)
            } else {
                self.unlookCharacter()
                rad.radicand = self.buildInternal(true)
            }
            return rad;
        } else if command == "left" {
            // Save the current inner while a new one gets built.
            let oldInner = currentInnerAtom
            currentInnerAtom = MTInner()
            currentInnerAtom!.leftBoundary = self.getBoundaryAtom("left")
            if currentInnerAtom!.leftBoundary == nil {
                return nil;
            }
            currentInnerAtom!.innerList = self.buildInternal(false)
            if currentInnerAtom!.rightBoundary == nil {
                // A right node would have set the right boundary so we must be missing the right node.
                let errorMessage = "Missing \\right"
                self.setError(.missingRight, message:errorMessage)
                return nil
            }
            // reinstate the old inner atom.
            let newInner = currentInnerAtom;
            currentInnerAtom = oldInner;
            return newInner;
        } else if command == "overline" {
            // The overline command has 1 arguments
            let over = MTOverLine()
            over.innerList = self.buildInternal(true)
            return over
        } else if command == "underline" {
            // The underline command has 1 arguments
            let under = MTUnderLine()
            under.innerList = self.buildInternal(true)
            return under
        } else if let direction = MTMathListBuilder.stretchyArrowCommands[command] {
            // \xrightarrow[아래]{위} — 대괄호 인자는 선택, 중괄호 인자는 필수.
            // 중괄호와 방향이 반대다: 화살표가 두 라벨 중 넓은 쪽에 맞춰 늘어난다.
            let underOver = MTUnderOver()
            underOver.stretchyArrow = direction
            underOver.type = .relation      // 화살표는 관계연산자 자리에 온다
            self.skipSpaces()
            if hasCharacters, string[currentCharIndex] == "[" {
                _ = getNextCharacter()
                underOver.under = self.buildInternal(false, stopChar: "]")
            }
            underOver.over = self.buildInternal(true)
            return underOver
        } else if let accent = MTMathListBuilder.stretchyAccentGlyphs[command] {
            // \underrightarrow·\overparen 계열 — 내용 폭에 맞춰 늘어나는 악센트.
            // MTAccent 는 위쪽만 다루므로 MTUnderOver 의 늘어나는 글리프로 만든다.
            guard let body = self.buildInternal(true) else { return nil }
            let underOver = MTUnderOver()
            underOver.innerList = body
            if accent.isOver { underOver.stretchyOver = accent.glyph }
            else { underOver.stretchyUnder = accent.glyph }
            return underOver
        } else if command == "overbrace" || command == "underbrace" {
            // 본체 폭에 맞춰 늘어나는 중괄호. `\overbrace{x}^{설명}` 처럼 뒤에 붙는 첨자는
            // 중괄호 **위/아래 가운데**로 가야 하므로(LaTeX 는 \mathop 으로 펼친다) 여기서
            // 직접 집어삼킨다. 그냥 두면 일반 첨자가 되어 오른쪽 위에 붙는다.
            guard let body = self.buildInternal(true) else { return nil }
            let underOver = MTUnderOver()
            underOver.innerList = body
            let isOver = command == "overbrace"
            // U+23DE TOP CURLY BRACKET / U+23DF BOTTOM CURLY BRACKET
            if isOver { underOver.stretchyOver = "\u{23DE}" } else { underOver.stretchyUnder = "\u{23DF}" }

            self.skipSpaces()
            if self.hasCharacters {
                let next = self.getNextCharacter()
                if (isOver && next == "^") || (!isOver && next == "_") {
                    if isOver { underOver.over = self.buildInternal(true) }
                    else { underOver.under = self.buildInternal(true) }
                } else {
                    self.unlookCharacter()
                }
            }
            return underOver
        } else if command == "mathstrut" {
            // \mathstrut 은 정의가 \vphantom{(} 다 — 인자를 받지 않고 여는 괄호 높이의
            // 보이지 않는 버팀목을 세운다. 줄마다 높이를 맞출 때 쓴다.
            let strut = MTDecorated()
            strut.kind = .verticalPhantom
            let paren = MTMathList()
            paren.add(MTMathAtomFactory.atom(forCharacter: "(") ?? MTMathAtom(type: .open, value: "("))
            strut.innerList = paren
            return strut
        } else if command == "idotsint" {
            // ∫⋯∫ — 단일 코드포인트가 없어 세 글자를 한 연산자로 묶는다.
            // makeLargeOp 이 여러 글자 nucleus 를 CTLine 으로 그리는 경로를 이미 갖고 있다.
            return MTLargeOperator(value: "\u{222B}\u{22EF}\u{222B}", limits: false)
        } else if let kind = MTMathListBuilder.decorationKinds[command] {
            // \boxed 와 \cancel 계열 — 내용은 그대로 두고 위에 선을 덧그린다.
            let decorated = MTDecorated()
            decorated.kind = kind
            guard let inner = self.buildInternal(true) else { return nil }
            decorated.innerList = inner
            return decorated
        } else if command == "overset" || command == "underset" || command == "stackrel" {
            // 셋 다 인자 순서가 {장식}{본체} 다.
            //
            // TeX 정의가 `\mathop{본체}\limits^{장식}` 이라, 큰 연산자의 위·아래 첨자와
            // 같은 조판 기계를 쓰는 MTUnderOver 로 만든다. 예전처럼 장식을 버리고 본체만
            // 남기면 `\overset{\text{def}}{=}` 가 그냥 `=` 가 돼 뜻이 달라진다.
            guard let decoration = self.buildInternal(true) else { return nil }
            guard let base = self.buildInternal(true) else { return nil }
            let underOver = MTUnderOver()
            underOver.innerList = base
            if command == "underset" {
                underOver.under = decoration
            } else {
                underOver.over = decoration
            }
            // 간격은 **본체의 성격을 물려받는다** — amsmath 의 \binrel@ 이 하는 일이다.
            // `\overset{?}{=}` 의 `=` 는 여전히 관계연산자라 앞뒤가 벌어져야 하고,
            // `\overset{a}{x}` 의 `x` 는 보통 원자라 벌어지면 안 된다.
            if command == "stackrel" {
                // \stackrel 은 정의부터 \mathrel 이라 본체와 무관하게 관계연산자다.
                underOver.type = .relation
            } else if base.atoms.count == 1,
                      case let baseType = base.atoms[0].type,
                      baseType == .relation || baseType == .binaryOperator {
                underOver.type = baseType
            }
            return underOver
        } else if command == "substack" {
            // \substack reads ONE braced argument containing rows separated by \\
            // Similar to how \frac reads {numerator}{denominator}

            // Read the braced content using standard pattern
            let content = self.buildInternal(true)

            if content == nil {
                return nil
            }

            // The content may already be a table if \\ was encountered
            // Check if we got a table from the \\ parsing
            if content!.atoms.count == 1, let tableAtom = content!.atoms.first as? MTMathTable {
                // \substack 의 각 줄은 **가운데 정렬**이다(LaTeX amsmath 정의). \\ 로 만들어진
                // 표는 기본이 왼쪽 정렬이라 그대로 두면 \sum_{\substack{i<n \\ j<m}} 의
                // 두 줄이 왼쪽에 붙어 어긋난다.
                for col in 0..<tableAtom.numColumns { tableAtom.set(alignment: .center, forColumn: col) }
                return tableAtom
            }

            // Otherwise, single row - wrap in table
            var rows = [[MTMathList]]()
            rows.append([content!])

            var error: NSError? = self.error
            let table = MTMathAtomFactory.table(withEnvironment: nil, rows: rows, error: &error)
            if table == nil && self.error == nil {
                self.error = error
                return nil
            }

            return table
        } else if command == "begin" {
            guard var env = self.readEnvironment() else { return nil }

            // 디스플레이 환경의 별표형(align*·equation* 등)은 **번호를 안 붙인다**는 뜻일
            // 뿐이라 조판이 같다. 앱에는 번호를 붙일 자리가 없으니 별을 떼고 같이 다룬다.
            // (matrix* 계열의 별표는 뜻이 달라 — 열 정렬 인자를 받는다 — 건드리지 않는다.)
            if env.hasSuffix("*"), MTMathListBuilder.numberlessEnvironments.contains(String(env.dropLast())) {
                env = String(env.dropLast())
            }
            // alignat 은 열 쌍 개수를 인자로 받는다: \begin{alignat}{2}. 읽고 버린다 —
            // 우리 표는 열 수를 내용에서 알아낸다.
            if env == "alignat", readRawGroup() == nil { self.error = nil }

            // array·subarray 는 열 지정이 **필수 인자**다: \begin{array}{cc}
            var columnAlignments: [MTColumnAlignment]? = nil
            if env == "array" || env == "subarray" {
                columnAlignments = self.readColumnSpec()
                if columnAlignments == nil { return nil }
            }
            // 별표형 행렬(matrix* 등)은 대괄호로 정렬을 한 번에 받는다.
            var alignment: MTColumnAlignment? = nil
            if env.hasSuffix("*") {
                alignment = self.readOptionalAlignment()
                if self.error != nil { return nil }
            }
            let table = self.buildTable(env: env, alignment: alignment,
                                        columnAlignments: columnAlignments,
                                        firstList: nil, isRow: false)
            return table
        } else if command == "color" {
            // A color command has 2 arguments
            let mathColor = MTMathColor()
            let color = self.readColor()
            if color == nil {
                return nil;
            }
            mathColor.colorString = color!
            mathColor.innerList = self.buildInternal(true)
            return mathColor
        } else if command == "textcolor" {
            // A textcolor command has 2 arguments
            let mathColor = MTMathTextColor()
            let color = self.readColor()
            if color == nil {
                return nil;
            }
            mathColor.colorString = color!
            mathColor.innerList = self.buildInternal(true)
            return mathColor
        } else if command == "colorbox" {
            // A color command has 2 arguments
            let mathColorbox = MTMathColorbox()
            let color = self.readColor()
            if color == nil {
                return nil;
            }
            mathColorbox.colorString = color!
            mathColorbox.innerList = self.buildInternal(true)
            return mathColorbox
        } else if command == "pmod" {
            // A pmod command has 1 argument - creates (mod n)
            let inner = MTInner()
            inner.leftBoundary = MTMathAtomFactory.boundary(forDelimiter: "(")
            inner.rightBoundary = MTMathAtomFactory.boundary(forDelimiter: ")")

            let innerList = MTMathList()

            // Add the "mod" operator (upright text)
            let modOperator = MTMathAtomFactory.atom(forLatexSymbol: "mod")!
            innerList.add(modOperator)

            // Add medium space between "mod" and argument (6mu)
            let space = MTMathSpace(space: 6.0)
            innerList.add(space)

            // Parse the argument from braces
            let argument = self.buildInternal(true)
            if let argList = argument {
                innerList.append(argList)
            }

            inner.innerList = innerList
            return inner
        } else if command == "not" {
            // Handle \not command with lookahead for comprehensive negation support
            let nextCommand = self.peekNextCommand()

            if let negatedUnicode = Self.notCombinations[nextCommand] {
                self.consumeNextCommand() // Remove base symbol from stream
                return MTMathAtom(type: .relation, value: negatedUnicode)
            } else {
                let errorMessage = "Unsupported \\not\\\(nextCommand) combination"
                self.setError(.invalidCommand, message: errorMessage)
                return nil
            }
        } else if let sizeMultiplier = Self.delimiterSizeCommands[command] {
            // Handle \big, \Big, \bigg, \Bigg and their variants
            let delim = self.readDelimiter()
            if delim == nil {
                let errorMessage = "Missing delimiter for \\\(command)"
                self.setError(.missingDelimiter, message: errorMessage)
                return nil
            }
            let boundary = MTMathAtomFactory.boundary(forDelimiter: delim!)
            if boundary == nil {
                let errorMessage = "Invalid delimiter for \\\(command): \(delim!)"
                self.setError(.invalidDelimiter, message: errorMessage)
                return nil
            }

            // Create MTInner with explicit delimiter height
            let inner = MTInner()

            // Determine if this is a left, right, or middle delimiter based on command suffix
            let isLeft = command.hasSuffix("l")
            let isRight = command.hasSuffix("r")
            // let isMiddle = command.hasSuffix("m")  // For future use

            if isLeft {
                inner.leftBoundary = boundary
                inner.rightBoundary = MTMathAtomFactory.boundary(forDelimiter: ".")
            } else if isRight {
                inner.leftBoundary = MTMathAtomFactory.boundary(forDelimiter: ".")
                inner.rightBoundary = boundary
            } else {
                // For \big, \Big, \bigg, \Bigg and \bigm variants, use the delimiter on both sides
                // but with empty inner content - it's just a sized delimiter
                inner.leftBoundary = boundary
                inner.rightBoundary = MTMathAtomFactory.boundary(forDelimiter: ".")
            }

            inner.innerList = MTMathList()
            inner.delimiterHeight = sizeMultiplier  // Store multiplier, typesetter will compute actual height

            return inner
        } else {
            let errorMessage = "Invalid command \\\(command)"
            self.setError(.invalidCommand, message:errorMessage)
            return nil;
        }
    }

    mutating func readColor() -> String? {
        if !self.expectCharacter("{") {
            // We didn't find an opening brace, so no env found.
            self.setError(.characterNotFound, message:"Missing {")
            return nil;
        }
        
        // Ignore spaces and nonascii.
        self.skipSpaces()
        
        // a string of all upper and lower case characters.
        var mutable = ""
        while self.hasCharacters {
            let ch = self.getNextCharacter()
            if ch == "#" || (ch >= "A" && ch <= "Z") || (ch >= "a" && ch <= "z") || (ch >= "0" && ch <= "9") {
                mutable.append(ch)  // appendString:[NSString stringWithCharacters:&ch length:1]];
            } else {
                // we went too far
                self.unlookCharacter()
                break;
            }
        }
        
        if !self.expectCharacter("}") {
            // We didn't find an closing brace, so invalid format.
            self.setError(.characterNotFound, message:"Missing }")
            return nil;
        }
        return mutable;
    }

    mutating func skipSpaces() {
        while self.hasCharacters {
            let ch = self.getNextCharacter().utf32Char
            // Skip whitespace and control characters only.
            //
            // Non-ASCII used to be skipped here too, which silently *ate* content: "\left한(x\right)"
            // re-serialised as "\left( x\right)" — the 한 was gone with no error, and "\color{빨강}{x}"
            // collapsed to "{}". Callers use this to step over layout whitespace, not to discard text,
            // so anything meaningful must be handed back. Now such input produces a precise error
            // ("Invalid delimiter for left: 한") that the caller can surface or fall back on, which is
            // strictly better than losing characters without a trace.
            //
            // This completes the CJK work started in the builder's main loop: parsing accepts
            // non-ASCII as ordinary atoms, so the scanner must stop treating it as whitespace.
            if ch < 0x21 {
                continue;
            } else {
                self.unlookCharacter()
                return;
            }
        }
    }
    
    static var fractionCommands: [String:[Character]] {
        [
            "over": [],
            "atop" : [],
            "choose" : [ "(", ")"],
            "brack" : [ "[", "]"],
            "brace" : [ "{", "}"]
        ]
    }
    
    mutating func stopCommand(_ command: String, list:MTMathList, stopChar:Character?) -> MTMathList? {
        if command == "right" {
            if currentInnerAtom == nil {
                let errorMessage = "Missing \\left";
                self.setError(.missingLeft, message:errorMessage)
                return nil;
            }
            currentInnerAtom!.rightBoundary = self.getBoundaryAtom("right")
            if currentInnerAtom!.rightBoundary == nil {
                return nil;
            }
            // return the list read so far.
            return list
        } else if let delims = Self.fractionCommands[command] {
            var frac:MTFraction! = nil;
            if command == "over" {
                frac = MTFraction()
            } else {
                frac = MTFraction(hasRule: false)
            }
            if delims.count == 2 {
                frac.leftDelimiter = String(delims[0])
                frac.rightDelimiter = String(delims[1])
            }
            frac.numerator = list;
            frac.denominator = self.buildInternal(false, stopChar: stopChar)
            if error != nil {
                return nil;
            }
            let fracList = MTMathList()
            fracList.add(frac)
            return fracList
        } else if command == "\\" || command == "cr" {
            if currentEnv != nil {
                // Stop the current list and increment the row count
                currentEnv!.numRows+=1
                return list
            } else {
                // Create a new table with the current list and a default env
                if let table = self.buildTable(env: nil, firstList:list, isRow:true) {
                    return MTMathList(atom: table)
                }
            }
        } else if command == "end" {
            if currentEnv == nil {
                let errorMessage = "Missing \\begin";
                self.setError(.missingBegin, message:errorMessage)
                return nil
            }
            let env = self.readEnvironment()
            if env == nil {
                return nil
            }
            // \begin 쪽에서 별표를 떼고 시작한 환경은 \end 쪽도 같이 떼고 비교한다.
            // 안 그러면 `\begin{align*}…\end{align*}` 이 이름 불일치로 죽는다.
            var endName = env!
            if endName.hasSuffix("*"),
               MTMathListBuilder.numberlessEnvironments.contains(String(endName.dropLast())) {
                endName = String(endName.dropLast())
            }
            if endName != currentEnv!.envName {
                let errorMessage = "Begin environment name \(currentEnv!.envName ?? "(none)") does not match end name: \(env!)"
                self.setError(.invalidEnv, message:errorMessage)
                return nil
            }
            // Finish the current environment.
            currentEnv!.ended = true
            return list
        }
        return nil
    }

    // Applies the modifier to the atom. Returns true if modifier applied.
    mutating func applyModifier(_ modifier:String, atom:MTMathAtom?) -> Bool {
        if modifier == "limits" {
            if atom?.type != .largeOperator {
                let errorMessage = "Limits can only be applied to an operator."
                self.setError(.invalidLimits, message:errorMessage)
            } else {
                let op = atom as! MTLargeOperator
                op.limits = true
            }
            return true
        } else if modifier == "nolimits" {
            if atom?.type != .largeOperator {
                let errorMessage = "No limits can only be applied to an operator."
                self.setError(.invalidLimits, message:errorMessage)
            } else {
                let op = atom as! MTLargeOperator
                op.limits = false
            }
            return true
        }
        return false
    }

    mutating func setError(_ code:MTParseErrors, message:String) {
        // Only record the first error.
        if error == nil {
            error = NSError(domain: MTParseError, code: code.rawValue, userInfo: [ NSLocalizedDescriptionKey : message ])
        }
    }
    
    mutating func atom(forCommand command: String) -> MTMathAtom? {
        if let atom = MTMathAtomFactory.atom(forLatexSymbol: command) {
            return atom
        }
        if let accent = MTMathAtomFactory.accent(withName: command) {
            accent.innerList = self.buildInternal(true)
            return accent
        } else if command == "frac" {
            let frac = MTFraction()
            frac.numerator = self.buildInternal(true)
            frac.denominator = self.buildInternal(true)
            return frac
        } else if command == "cfrac" {
            let frac = MTFraction()
            frac.isContinuedFraction = true

            // Parse optional alignment parameter [l], [r], [c]
            skipSpaces()
            if hasCharacters && string[currentCharIndex] == "[" {
                _ = getNextCharacter() // consume '['
                if hasCharacters {
                    let alignmentChar = getNextCharacter()
                    if alignmentChar == "l" || alignmentChar == "r" || alignmentChar == "c" {
                        frac.alignment = String(alignmentChar)
                    }
                }
                // Consume closing ']'
                if hasCharacters && string[currentCharIndex] == "]" {
                    _ = getNextCharacter()
                }
            }

            frac.numerator = self.buildInternal(true)
            frac.denominator = self.buildInternal(true)
            return frac
        } else if command == "dfrac" {
            // Display-style fraction command has 2 arguments
            let frac = MTFraction()
            let numerator = self.buildInternal(true)
            let denominator = self.buildInternal(true)

            // Prepend \displaystyle to force display mode rendering
            let displayStyle = MTMathStyle(style: .display)
            numerator?.insert(displayStyle, at: 0)
            denominator?.insert(displayStyle, at: 0)

            frac.numerator = numerator
            frac.denominator = denominator
            return frac
        } else if command == "tfrac" {
            // Text-style fraction command has 2 arguments
            let frac = MTFraction()
            let numerator = self.buildInternal(true)
            let denominator = self.buildInternal(true)

            // Prepend \textstyle to force text mode rendering
            let textStyle = MTMathStyle(style: .text)
            numerator?.insert(textStyle, at: 0)
            denominator?.insert(textStyle, at: 0)

            frac.numerator = numerator
            frac.denominator = denominator
            return frac
        } else if command == "binom" {
            let frac = MTFraction(hasRule: false)
            frac.numerator = self.buildInternal(true)
            frac.denominator = self.buildInternal(true)
            frac.leftDelimiter = "("
            frac.rightDelimiter = ")"
            return frac
        } else if command == "bra" {
            // Dirac bra notation: \bra{psi} -> ⟨psi|
            let inner = MTInner()
            inner.leftBoundary = MTMathAtomFactory.boundary(forDelimiter: "langle")
            inner.rightBoundary = MTMathAtomFactory.boundary(forDelimiter: "|")
            inner.innerList = self.buildInternal(true)
            return inner
        } else if command == "ket" {
            // Dirac ket notation: \ket{psi} -> |psi⟩
            let inner = MTInner()
            inner.leftBoundary = MTMathAtomFactory.boundary(forDelimiter: "|")
            inner.rightBoundary = MTMathAtomFactory.boundary(forDelimiter: "rangle")
            inner.innerList = self.buildInternal(true)
            return inner
        } else if command == "braket" {
            // Dirac braket notation: \braket{phi}{psi} -> ⟨phi|psi⟩
            let inner = MTInner()
            inner.leftBoundary = MTMathAtomFactory.boundary(forDelimiter: "langle")
            inner.rightBoundary = MTMathAtomFactory.boundary(forDelimiter: "rangle")
            let phi = self.buildInternal(true)
            let psi = self.buildInternal(true)
            let content = MTMathList()
            if let phiList = phi {
                for atom in phiList.atoms {
                    content.add(atom)
                }
            }
            content.add(MTMathAtom(type: .ordinary, value: "|"))
            if let psiList = psi {
                for atom in psiList.atoms {
                    content.add(atom)
                }
            }
            inner.innerList = content
            return inner
        } else if command == "operatorname" || command == "operatorname*" {
            // \operatorname{name} creates a custom operator with proper spacing
            // \operatorname*{name} creates an operator with limits above/below
            let hasLimits = command.hasSuffix("*")

            let content = self.buildInternal(true)
            var operatorName = ""
            if let atoms = content?.atoms {
                for atom in atoms {
                    operatorName += atom.nucleus
                }
            }
            if operatorName.isEmpty {
                self.setError(.invalidCommand, message: "Missing operator name for \\operatorname")
                return nil
            }
            return MTLargeOperator(value: operatorName, limits: hasLimits)
        } else if command == "sqrt" {
            let rad = MTRadical()
            guard self.hasCharacters else {
                rad.radicand = self.buildInternal(true)
                return rad
            }
            let char = self.getNextCharacter()
            if char == "[" {
                rad.degree = self.buildInternal(false, stopChar: "]")
                rad.radicand = self.buildInternal(true)
            } else {
                self.unlookCharacter()
                rad.radicand = self.buildInternal(true)
            }
            return rad
        } else if command == "left" {
            let oldInner = self.currentInnerAtom
            self.currentInnerAtom = MTInner()
            self.currentInnerAtom?.leftBoundary = self.getBoundaryAtom("left")
            if self.currentInnerAtom?.leftBoundary == nil {
                return nil
            }
            self.currentInnerAtom!.innerList = self.buildInternal(false)
            if self.currentInnerAtom?.rightBoundary == nil {
                self.setError(.missingRight, message: "Missing \\right")
                return nil
            }
            let newInner = self.currentInnerAtom
            currentInnerAtom = oldInner
            return newInner
        } else if command == "overline" {
            let over = MTOverLine()
            over.innerList = self.buildInternal(true)
            
            return over
        } else if command == "underline" {
            let under = MTUnderLine()
            under.innerList = self.buildInternal(true)

            return under
        } else if command == "begin" {
            if let env = self.readEnvironment() {
                // Check if this is a starred matrix environment and read optional alignment
                var alignment: MTColumnAlignment? = nil
                if env.hasSuffix("*") {
                    alignment = self.readOptionalAlignment()
                    if self.error != nil {
                        return nil
                    }
                }

                let table = self.buildTable(env: env, alignment: alignment, firstList: nil, isRow: false)
                return table
            } else {
                return nil
            }
        } else if command == "color" {
            // A color command has 2 arguments
            let mathColor = MTMathColor()
            mathColor.colorString = self.readColor()!
            mathColor.innerList = self.buildInternal(true)
            return mathColor
        } else if command == "colorbox" {
            // A color command has 2 arguments
            let mathColorbox = MTMathColorbox()
            mathColorbox.colorString = self.readColor()!
            mathColorbox.innerList = self.buildInternal(true)
            return mathColorbox
        } else {
            self.setError(.invalidCommand, message: "Invalid command \\\(command)")
            return nil
        }
    }
    
    mutating func readEnvironment() -> String? {
        if !self.expectCharacter("{") {
            // We didn't find an opening brace, so no env found.
            self.setError(.characterNotFound, message: "Missing {")
            return nil
        }

        self.skipSpaces()
        let env = self.readString()

        if !self.expectCharacter("}") {
            // We didn"t find an closing brace, so invalid format.
            self.setError(.characterNotFound, message: "Missing }")
            return nil;
        }
        return env
    }

    /// Reads optional alignment parameter for starred matrix environments: [r], [l], or [c]
    /// `\begin{array}{lcr|}` 의 열 지정을 읽는다.
    ///
    /// `l`·`c`·`r` 만 정렬로 받고, 세로줄(`|`)과 열 사이 삽입(`@{…}`)은 **건너뛴다** —
    /// 조판기가 표에 세로줄을 그릴 방법이 없어서, 받아 봐야 못 지킨다. 무시하고 내용을
    /// 살리는 쪽이 통째로 실패하는 것보다 낫다.
    /// `\ce`·`\SI`·`\si`·`\num` 을 LaTeX 로 옮겨 리스트로 만든다. 해당 명령이 아니면 nil.
    mutating func expandScienceNotation(_ command: String) -> MTMathList? {
        switch command {
        case "ce":
            guard let source = readRawGroup() else { return nil }
            return parseTranspiled(MTChemFormula.toLatex(source), fallback: source)

        // physics 패키지 — 물리·전자공학 강의에 상시로 나온다. 전부 매크로 전개라
        // 옮긴 결과가 곧 일반 LaTeX 다.
        case "dv", "pdv", "odv":
            // \dv{f}{x} · \dv[2]{f}{x}. 차수는 대괄호 선택 인자.
            let d = (command == "pdv") ? "\\partial" : "d"
            var order = ""
            self.skipSpaces()
            if hasCharacters, string[currentCharIndex] == "[" {
                _ = getNextCharacter()
                var text = ""
                while hasCharacters {
                    let ch = getNextCharacter()
                    if ch == "]" { break }
                    text.append(ch)
                }
                order = text
            }
            guard let f = readRawGroup() else { return nil }
            let x = readRawGroup()
            let power = order.isEmpty ? "" : "^{\(order)}"
            let numerator = x == nil ? "\(d)\(power)" : "\(d)\(power) \(f)"
            let denominator = x == nil ? "\(d) \(f)\(power)" : "\(d) \(x!)\(power)"
            return parseTranspiled("\\frac{\(numerator)}{\(denominator)}", fallback: f)

        case "abs":
            guard let body = readRawGroup() else { return nil }
            return parseTranspiled("\\left|\(body)\\right|", fallback: body)

        case "norm":
            guard let body = readRawGroup() else { return nil }
            return parseTranspiled("\\left\\|\(body)\\right\\|", fallback: body)

        case "ceil":
            guard let body = readRawGroup() else { return nil }
            return parseTranspiled("\\left\\lceil \(body)\\right\\rceil", fallback: body)

        case "floor":
            guard let body = readRawGroup() else { return nil }
            return parseTranspiled("\\left\\lfloor \(body)\\right\\rfloor", fallback: body)

        case "set":
            guard let body = readRawGroup() else { return nil }
            return parseTranspiled("\\left\\{\(body)\\right\\}", fallback: body)

        case "braket", "ip":
            guard let a = readRawGroup() else { return nil }
            guard let b = readRawGroup() else {
                return parseTranspiled("\\left\\langle \(a)\\right\\rangle", fallback: a)
            }
            return parseTranspiled("\\left\\langle \(a)\\middle|\(b)\\right\\rangle",
                                   fallback: "\(a)|\(b)")

        case "ev", "expval":
            guard let body = readRawGroup() else { return nil }
            return parseTranspiled("\\left\\langle \(body)\\right\\rangle", fallback: body)

        case "comm":
            guard let a = readRawGroup(), let b = readRawGroup() else { return nil }
            return parseTranspiled("\\left[\(a),\(b)\\right]", fallback: "[\(a),\(b)]")

        case "acomm", "poissonbracket":
            guard let a = readRawGroup(), let b = readRawGroup() else { return nil }
            return parseTranspiled("\\left\\{\(a),\(b)\\right\\}", fallback: "{\(a),\(b)}")

        case "middle":
            // `\left\{ x \middle| P \right\}` — 집합 표기에 늘 나온다. 안쪽 구분자를
            // 내용 높이에 맞춰 늘리려면 MTInner 를 쪼개야 하는데, 거기까지 가지 않고
            // **보통 크기 구분자**로 둔다. 늘어나지 않을 뿐 기호와 자리는 맞는다.
            self.skipSpaces()
            let name = hasCharacters ? readDelimiter() : nil
            let glyph = name.flatMap { MTMathAtomFactory.delimiters[$0] } ?? "|"
            return MTMathList(atom: MTMathAtom(type: .ordinary, value: glyph))

        case "mathord", "mathbin", "mathrel", "mathop", "mathopen", "mathclose", "mathpunct":
            // 원자의 **간격 등급**을 바꾼다. 표준 LaTeX 인데 없었다.
            // 화학 결합선이 대표적인 쓰임이다 — `=` 는 어디서든 관계연산자로 잡혀
            // 양쪽에 5mu 가 붙는데, 결합선은 원자에 바짝 붙어야 한다.
            guard let sublist = self.buildInternal(true) else { return nil }
            let newType: MTMathAtomType
            switch command {
            case "mathbin":   newType = .binaryOperator
            case "mathrel":   newType = .relation
            case "mathop":    newType = .largeOperator
            case "mathopen":  newType = .open
            case "mathclose": newType = .close
            case "mathpunct": newType = .punctuation
            default:          newType = .ordinary
            }
            // 원자가 하나일 때만 등급을 바꾼다. 여럿이면 무엇의 등급인지 모호해서
            // 건드리지 않는다 — 내용을 잃는 것보다 간격이 조금 다른 게 낫다.
            if sublist.atoms.count == 1 { sublist.atoms[0].type = newType }
            return sublist

        case "notag", "nonumber":
            // 번호를 붙이지 않는다는 지시. 앱에는 번호가 없으니 아무 일도 하지 않는다.
            // 다만 **오류를 내면 안 된다** — 수식 하나가 통째로 날아간다.
            return MTMathList()

        case "grad":
            return parseTranspiled("\\nabla ", fallback: "grad")
        case "divergence":
            return parseTranspiled("\\nabla \\cdot ", fallback: "div")
        case "curl":
            return parseTranspiled("\\nabla \\times ", fallback: "curl")
        case "laplacian":
            return parseTranspiled("\\nabla^{2}", fallback: "laplacian")

        case "SI", "qty":
            guard let value = readRawGroup(), let unit = readRawGroup() else { return nil }
            return parseTranspiled(MTUnitNotation.toLatex(value: value, unit: unit),
                                   fallback: "\(value) \(unit)")

        case "si", "unit":
            guard let unit = readRawGroup() else { return nil }
            return parseTranspiled(MTUnitNotation.units(unit), fallback: unit)

        case "num":
            guard let value = readRawGroup() else { return nil }
            return parseTranspiled(MTUnitNotation.number(value), fallback: value)

        case "SIrange", "numrange", "qtyrange":
            // \SIrange{1}{2}{\meter} → 1–2 m
            guard let from = readRawGroup(), let to = readRawGroup() else { return nil }
            let unit = (command == "numrange") ? nil : readRawGroup()
            let range = "\(MTUnitNotation.number(from))\u{2013}\(MTUnitNotation.number(to))"
            let latex = unit.map { "\(range)\\,\(MTUnitNotation.units($0))" } ?? range
            return parseTranspiled(latex, fallback: "\(from)-\(to)")

        default:
            return nil
        }
    }

    /// `{…}` 안을 **해석하지 않고 원문 그대로** 읽는다. 중괄호 짝은 맞춘다.
    ///
    /// `\ce`·`\SI` 는 LaTeX 가 아닌 별도 문법이라, 일반 파서에 태우기 전에 원문을
    /// 통째로 받아 옮겨야 한다.
    mutating func readRawGroup() -> String? {
        self.skipSpaces()
        guard hasCharacters, string[currentCharIndex] == "{" else { return nil }
        _ = getNextCharacter()

        var text = ""
        var depth = 1
        while hasCharacters {
            let ch = getNextCharacter()
            if ch == "{" { depth += 1 }
            if ch == "}" { depth -= 1; if depth == 0 { return text } }
            text.append(ch)
        }
        self.setError(.mismatchBraces, message: "Missing } in argument")
        return nil
    }

    /// 옮긴 LaTeX 를 파싱해 리스트로 만든다. 실패하면 원문을 정립 텍스트로 보여 준다 —
    /// 화학식 하나 때문에 수식 전체를 잃지 않는 게 우선이다.
    func parseTranspiled(_ latex: String, fallback: String) -> MTMathList {
        var error: NSError?
        if let list = MTMathListBuilder.build(fromString: latex, error: &error), error == nil {
            return list
        }
        let escaped = fallback.replacingOccurrences(of: "{", with: "")
            .replacingOccurrences(of: "}", with: "")
        var fallbackError: NSError?
        return MTMathListBuilder.build(fromString: "\\text{\(escaped)}", error: &fallbackError)
            ?? MTMathList()
    }

    mutating func readColumnSpec() -> [MTColumnAlignment]? {
        self.skipSpaces()
        guard hasCharacters, string[currentCharIndex] == "{" else {
            self.setError(.characterNotFound, message: "Missing column specification for array")
            return nil
        }
        _ = getNextCharacter()   // '{'

        var alignments = [MTColumnAlignment]()
        while hasCharacters {
            let ch = getNextCharacter()
            switch ch {
            case "}":  return alignments
            case "l":  alignments.append(.left)
            case "c":  alignments.append(.center)
            case "r":  alignments.append(.right)
            case "|", " ":
                continue     // 세로줄·공백은 무시
            case "@", "p", "m", "b":
                // @{…}, p{너비} 등은 인자를 하나 더 먹는다. 통째로 건너뛴다.
                self.skipSpaces()
                if hasCharacters, string[currentCharIndex] == "{" {
                    _ = getNextCharacter()
                    var depth = 1
                    while hasCharacters && depth > 0 {
                        let c = getNextCharacter()
                        if c == "{" { depth += 1 } else if c == "}" { depth -= 1 }
                    }
                }
                if ch != "@" { alignments.append(.left) }   // p/m/b 는 한 열을 만든다
            default:
                continue     // 모르는 글자는 무시 — 열 지정 하나로 수식을 버리지 않는다
            }
        }
        self.setError(.characterNotFound, message: "Missing } in array column specification")
        return nil
    }

    mutating func readOptionalAlignment() -> MTColumnAlignment? {
        self.skipSpaces()

        // Check if there's an opening bracket
        guard hasCharacters && string[currentCharIndex] == "[" else {
            return nil
        }

        _ = getNextCharacter()  // consume '['
        self.skipSpaces()

        guard hasCharacters else {
            self.setError(.characterNotFound, message: "Missing alignment specifier after [")
            return nil
        }

        let alignChar = getNextCharacter()
        let alignment: MTColumnAlignment?

        switch alignChar {
        case "l":
            alignment = .left
        case "c":
            alignment = .center
        case "r":
            alignment = .right
        default:
            self.setError(.invalidEnv, message: "Invalid alignment specifier: \(alignChar). Must be l, c, or r")
            return nil
        }

        self.skipSpaces()

        if !self.expectCharacter("]") {
            self.setError(.characterNotFound, message: "Missing ] after alignment specifier")
            return nil
        }

        return alignment
    }
    
    func MTAssertNotSpace(_ ch: Character) {
        // Only the lower bound is a real invariant: callers guarantee whitespace has been skipped.
        // The old upper bound (<= 0x7E) additionally asserted "ASCII", which now traps in DEBUG the
        // moment CJK reaches a delimiter/environment scanner — and CJK reaching those points is
        // exactly what skipSpaces() was changed to allow.
        assert(ch >= "\u{21}", "Expected non-space character \(ch)")
    }
    
    mutating func buildTable(env: String?, alignment: MTColumnAlignment? = nil,
                             columnAlignments: [MTColumnAlignment]? = nil,
                             firstList: MTMathList?, isRow: Bool) -> MTMathAtom? {
        // Save the current env till an new one gets built.
        let oldEnv = self.currentEnv

        currentEnv = MTEnvProperties(name: env, alignment: alignment, columnAlignments: columnAlignments)
        
        var currentRow = 0
        var currentCol = 0
        
        var rows = [[MTMathList]]()
        rows.append([MTMathList]())
        if firstList != nil {
            rows[currentRow].append(firstList!)
            if isRow {
                currentEnv!.numRows+=1
                currentRow+=1
                rows.append([MTMathList]())
            } else {
                currentCol+=1
            }
        }
        while !currentEnv!.ended && self.hasCharacters {
            let list = self.buildInternal(false)
            if list == nil {
                // If there is an error building the list, bail out early.
                return nil
            }
            rows[currentRow].append(list!)
            currentCol+=1
            if currentEnv!.numRows > currentRow {
                currentRow = currentEnv!.numRows
                rows.append([MTMathList]())
                currentCol = 0
            }
        }
        
        if !currentEnv!.ended && currentEnv!.envName != nil {
            self.setError(.missingEnd, message: "Missing \\end")
            return nil
        }
        
        var error:NSError? = self.error
        let table = MTMathAtomFactory.table(withEnvironment: currentEnv?.envName,
                                            alignment: currentEnv?.alignment,
                                            columnAlignments: currentEnv?.columnAlignments,
                                            rows: rows, error: &error)
        if table == nil && self.error == nil {
            self.error = error
            return nil
        }
        self.currentEnv = oldEnv
        return table
    }
    
    mutating func getBoundaryAtom(_ delimiterType: String) -> MTMathAtom? {
        let delim = self.readDelimiter()
        if delim == nil {
            let errorMessage = "Missing delimiter for \\\(delimiterType)"
            self.setError(.missingDelimiter, message:errorMessage)
            return nil
        }
        let boundary = MTMathAtomFactory.boundary(forDelimiter: delim!)
        if boundary == nil {
            let errorMessage = "Invalid delimiter for \(delimiterType): \(delim!)"
            self.setError(.invalidDelimiter, message:errorMessage)
            return nil
        }
        return boundary
    }
    
    mutating func readDelimiter() -> String? {
        self.skipSpaces()
        while self.hasCharacters {
            let char = self.getNextCharacter()
            MTAssertNotSpace(char)
            if char == "\\" {
                let command = self.readCommand()
                if command == "|" {
                    return "||"
                }
                return command
            } else {
                return String(char)
            }
        }
        return nil
    }
    
    mutating func readCommand() -> String {
        // ':' is here for \: (medium space). Without it the backslash was consumed and the
        // command name came back empty, so "a\:b" failed the whole expression with
        // `Invalid command \` — an error message that also defeats caller-side recovery,
        // since there is no command name to strip.
        let singleChars = "{}$#%_| ,>;!:\\"
        if self.hasCharacters {
            let char = self.getNextCharacter()
            if let _ = singleChars.firstIndex(of: char)  {
                return String(char)
            } else {
                self.unlookCharacter()
            }
        }
        return self.readString()
    }
    
    mutating func readString() -> String {
        // a string of all upper and lower case characters (and asterisks for starred environments)
        var output = ""
        while self.hasCharacters {
            let char = self.getNextCharacter()
            if char.isLowercase || char.isUppercase || char == "*" {
                output.append(char)
            } else {
                self.unlookCharacter()
                break
            }
        }
        return output
    }
}
