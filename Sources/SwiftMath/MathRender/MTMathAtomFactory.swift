//
//  Created by Mike Griebling on 2022-12-31.
//  Translated from an Objective-C implementation by Kostub Deshmukh.
//
//  This software may be modified and distributed under the terms of the
//  MIT license. See the LICENSE file for details.
//

import Foundation

/** A factory to create commonly used MTMathAtoms. */
public class MTMathAtomFactory {
    
    public static let aliases = [
        "lnot" : "neg",
        "land" : "wedge",
        "lor" : "vee",
        "ne" : "neq",
        "le" : "leq",
        "ge" : "geq",
        "lbrace" : "{",
        "rbrace" : "}",
        "Vert" : "|",
        "gets" : "leftarrow",
        "to" : "rightarrow",
        "iff" : "Longleftrightarrow",
        "AA" : "angstrom",

        // ── 표기 변형 별칭 (2026-07-26) ──────────────────────────────────────────
        // 같은 글리프를 가리키는 다른 철자는 심볼을 새로 만들지 않고 여기로 보낸다.
        // 역매핑(textToLatexSymbolName)이 오염되지 않고, 코드포인트 중복도 생기지 않는다.
        "dots" : "ldots", "dotsc" : "ldots", "dotso" : "ldots", "mathellipsis" : "ldots",
        "dotsb" : "cdots", "dotsi" : "cdots", "dotsm" : "cdots",
        "impliedby" : "Longleftarrow",
        "empty" : "emptyset", "exist" : "exists", "isin" : "in", "owns" : "ni",
        "hslash" : "hbar", "image" : "Im", "real" : "Re", "weierp" : "wp", "infin" : "infty",
        "plusmn" : "pm", "sdot" : "cdot",
        "thickapprox" : "approx", "thicksim" : "sim", "varpropto" : "propto",
        "vartriangle" : "triangle", "smallsetminus" : "setminus",
        "shortmid" : "mid", "shortparallel" : "parallel",
        "sub" : "subset", "sube" : "subseteq", "supe" : "supseteq",
        "lVert" : "Vert", "rVert" : "Vert", "lvert" : "vert", "rvert" : "vert",
        "Join" : "bowtie", "alef" : "aleph", "alefsym" : "aleph", "thetasym" : "vartheta",
        "lang" : "langle", "rang" : "rangle",
        "coloneq" : "coloneqq", "leadsto" : "rightsquigarrow", "lozenge" : "Diamond",
        "pounds" : "mathsterling", "llless" : "lll", "gggtr" : "ggg",
        "doteqdot" : "Doteq", "smallfrown" : "frown", "smallsmile" : "smile",
        "restriction" : "upharpoonright",
    ]
    
    public static let delimiters = [
        "." : "", // . means no delimiter
        "(" : "(",
        ")" : ")",
        "[" : "[",
        "]" : "]",
        "<" : "\u{2329}",
        ">" : "\u{232A}",
        "/" : "/",
        "\\" : "\\",
        "|" : "|",
        "lgroup" : "\u{27EE}",
        "rgroup" : "\u{27EF}",
        "||" : "\u{2016}",
        "Vert" : "\u{2016}",
        "vert" : "|",
        // \left\lVert … \right\rVert 은 구분자 조회에 별칭이 적용되지 않아 실패했다.
        // 별칭에만 넣지 말고 이 표에도 직접 넣는다.
        "lVert" : "\u{2016}",
        "rVert" : "\u{2016}",
        "lvert" : "|",
        "rvert" : "|",
        "uparrow" : "\u{2191}",
        "downarrow" : "\u{2193}",
        "updownarrow" : "\u{2195}",
        "Uparrow" : "\u{21D1}",
        "Downarrow" : "\u{21D3}",
        "Updownarrow" : "\u{21D5}",
        "backslash" : "\\",
        "rangle" : "\u{232A}",
        "langle" : "\u{2329}",
        "rbrace" : "}",
        "}" : "}",
        "{" : "{",
        "lbrace" : "{",
        "lceil" : "\u{2308}",
        "rceil" : "\u{2309}",
        "lfloor" : "\u{230A}",
        "rfloor" : "\u{230B}",
        // Corner brackets (amssymb)
        "ulcorner" : "\u{231C}",  // upper left corner
        "urcorner" : "\u{231D}",  // upper right corner
        "llcorner" : "\u{231E}",  // lower left corner
        "lrcorner" : "\u{231F}",  // lower right corner
        // Double square brackets (strachey brackets)
        "llbracket" : "\u{27E6}",  // left double bracket
        "rrbracket" : "\u{27E7}",  // right double bracket
    ]
    
    private static let delimValueLock = NSLock()
    static var _delimValueToName = [String: String]()
    public static var delimValueToName: [String: String] {
        if _delimValueToName.isEmpty {
            var output = [String: String]()
            for (key, value) in Self.delimiters {
                if let existingValue = output[value] {
                    if key.count > existingValue.count {
                        continue
                    } else if key.count == existingValue.count {
                        if key.compare(existingValue) == .orderedDescending {
                            continue
                        }
                    }
                }
                output[value] = key
            }
            // protect lazily loading table in a multi-thread concurrent environment
            delimValueLock.lock()
            defer { delimValueLock.unlock() }
            if _delimValueToName.isEmpty {
                _delimValueToName = output
            }
        }
        return _delimValueToName
    }
    
    public static let accents = [
        "grave" :  "\u{0300}",
        "acute" :  "\u{0301}",
        "hat" :  "\u{0302}",  // In our implementation hat and widehat behave the same.
        "tilde" :  "\u{0303}", // In our implementation tilde and widetilde behave the same.
        "bar" :  "\u{0304}",
        "breve" :  "\u{0306}",
        "dot" :  "\u{0307}",
        "ddot" :  "\u{0308}",
        "check" :  "\u{030C}",
        "vec" :  "\u{20D7}",
        "widehat" :  "\u{0302}",
        "widetilde" :  "\u{0303}",
        "overleftarrow" :  "\u{20D6}",      // Combining left arrow above
        "overrightarrow" :  "\u{20D7}",     // Combining right arrow above (same as vec)
        "overleftrightarrow" :  "\u{20E1}", // Combining left right arrow above
        // wideAccents 에는 있으나 이 표에 없어 도달할 수 없던 것들.
        "mathring" :  "\u{030A}",           // Combining ring above
        "dddot" :  "\u{20DB}",              // Combining three dots above
        "ddddot" :  "\u{20DC}",             // Combining four dots above
        "widecheck" :  "\u{030C}"           // check 와 같은 결합 caron
    ]
    
    private static let accentValueLock = NSLock()
    static var _accentValueToName: [String: String]? = nil
    public static var accentValueToName: [String: String] {
        if _accentValueToName == nil {
            var output = [String: String]()

            for (key, value) in Self.accents {
                if let existingValue = output[value] {
                    if key.count > existingValue.count {
                        continue
                    } else if key.count == existingValue.count {
                        if key.compare(existingValue) == .orderedDescending {
                            continue
                        }
                    }
                }
                output[value] = key
            }
            // protect lazily loading table in a multi-thread concurrent environment
            accentValueLock.lock()
            defer { accentValueLock.unlock() }
            if _accentValueToName == nil {
                _accentValueToName = output
            }
        }
        return _accentValueToName!
    }
    
    static var supportedLatexSymbolNames:[String] {
        let commands = MTMathAtomFactory.supportedLatexSymbols
        return commands.keys.map { String($0) }
    }
    
    static var supportedLatexSymbols: [String: MTMathAtom] = [
        // \square 는 사용자가 쓰는 기호(□)다. placeholder 원자는 편집기용 특수 타입이라
        // 조판·직렬화 경로가 다르므로 일반 기호로 둔다(placeholder() 자체는 분수·루트의
        // 빈칸 생성에 그대로 쓰인다).
        "square" : MTMathAtom(type: .ordinary, value: "\u{25A1}"),
        
         // Greek characters
        "alpha" : MTMathAtom(type: .variable, value: "\u{03B1}"),
        "beta" : MTMathAtom(type: .variable, value: "\u{03B2}"),
        "gamma" : MTMathAtom(type: .variable, value: "\u{03B3}"),
        "delta" : MTMathAtom(type: .variable, value: "\u{03B4}"),
        "varepsilon" : MTMathAtom(type: .variable, value: "\u{03B5}"),
        "zeta" : MTMathAtom(type: .variable, value: "\u{03B6}"),
        "eta" : MTMathAtom(type: .variable, value: "\u{03B7}"),
        "theta" : MTMathAtom(type: .variable, value: "\u{03B8}"),
        "iota" : MTMathAtom(type: .variable, value: "\u{03B9}"),
        "kappa" : MTMathAtom(type: .variable, value: "\u{03BA}"),
        "lambda" : MTMathAtom(type: .variable, value: "\u{03BB}"),
        "mu" : MTMathAtom(type: .variable, value: "\u{03BC}"),
        "nu" : MTMathAtom(type: .variable, value: "\u{03BD}"),
        "xi" : MTMathAtom(type: .variable, value: "\u{03BE}"),
        "omicron" : MTMathAtom(type: .variable, value: "\u{03BF}"),
        "pi" : MTMathAtom(type: .variable, value: "\u{03C0}"),
        "rho" : MTMathAtom(type: .variable, value: "\u{03C1}"),
        "varsigma" : MTMathAtom(type: .variable, value: "\u{03C2}"),
        "sigma" : MTMathAtom(type: .variable, value: "\u{03C3}"),
        "tau" : MTMathAtom(type: .variable, value: "\u{03C4}"),
        "upsilon" : MTMathAtom(type: .variable, value: "\u{03C5}"),
        "varphi" : MTMathAtom(type: .variable, value: "\u{03C6}"),
        "chi" : MTMathAtom(type: .variable, value: "\u{03C7}"),
        "psi" : MTMathAtom(type: .variable, value: "\u{03C8}"),
        "omega" : MTMathAtom(type: .variable, value: "\u{03C9}"),
        // We mark the following greek chars as ordinary so that we don't try
        // to automatically italicize them as we do with variables.
        // These characters fall outside the rules of italicization that we have defined.
        "epsilon" : MTMathAtom(type: .ordinary, value: "\u{0001D716}"),
        "vartheta" : MTMathAtom(type: .ordinary, value: "\u{0001D717}"),
        "phi" : MTMathAtom(type: .ordinary, value: "\u{0001D719}"),
        "varrho" : MTMathAtom(type: .ordinary, value: "\u{0001D71A}"),
        "varpi" : MTMathAtom(type: .ordinary, value: "\u{0001D71B}"),
        "varkappa" : MTMathAtom(type: .ordinary, value: "\u{03F0}"),
        // Note: digamma (U+03DD) and Digamma (U+03DC) are not supported by Latin Modern Math font

        // Capital greek characters
        "Gamma" : MTMathAtom(type: .variable, value: "\u{0393}"),
        "Delta" : MTMathAtom(type: .variable, value: "\u{0394}"),
        "Theta" : MTMathAtom(type: .variable, value: "\u{0398}"),
        "Lambda" : MTMathAtom(type: .variable, value: "\u{039B}"),
        "Xi" : MTMathAtom(type: .variable, value: "\u{039E}"),
        "Pi" : MTMathAtom(type: .variable, value: "\u{03A0}"),
        "Sigma" : MTMathAtom(type: .variable, value: "\u{03A3}"),
        "Upsilon" : MTMathAtom(type: .variable, value: "\u{03A5}"),
        "Phi" : MTMathAtom(type: .variable, value: "\u{03A6}"),
        "Psi" : MTMathAtom(type: .variable, value: "\u{03A8}"),
        "Omega" : MTMathAtom(type: .variable, value: "\u{03A9}"),

        // Open
        "lceil" : MTMathAtom(type: .open, value: "\u{2308}"),
        "lfloor" : MTMathAtom(type: .open, value: "\u{230A}"),
        "langle" : MTMathAtom(type: .open, value: "\u{27E8}"),
        "lgroup" : MTMathAtom(type: .open, value: "\u{27EE}"),

        // Close
        "rceil" : MTMathAtom(type: .close, value: "\u{2309}"),
        "rfloor" : MTMathAtom(type: .close, value: "\u{230B}"),
        "rangle" : MTMathAtom(type: .close, value: "\u{27E9}"),
        "rgroup" : MTMathAtom(type: .close, value: "\u{27EF}"),

        // Arrows
        "leftarrow" : MTMathAtom(type: .relation, value: "\u{2190}"),
        "uparrow" : MTMathAtom(type: .relation, value: "\u{2191}"),
        "rightarrow" : MTMathAtom(type: .relation, value: "\u{2192}"),
        "downarrow" : MTMathAtom(type: .relation, value: "\u{2193}"),
        "leftrightarrow" : MTMathAtom(type: .relation, value: "\u{2194}"),
        "updownarrow" : MTMathAtom(type: .relation, value: "\u{2195}"),
        "nwarrow" : MTMathAtom(type: .relation, value: "\u{2196}"),
        "nearrow" : MTMathAtom(type: .relation, value: "\u{2197}"),
        "searrow" : MTMathAtom(type: .relation, value: "\u{2198}"),
        "swarrow" : MTMathAtom(type: .relation, value: "\u{2199}"),
        "mapsto" : MTMathAtom(type: .relation, value: "\u{21A6}"),
        "Leftarrow" : MTMathAtom(type: .relation, value: "\u{21D0}"),
        "Uparrow" : MTMathAtom(type: .relation, value: "\u{21D1}"),
        "Rightarrow" : MTMathAtom(type: .relation, value: "\u{21D2}"),
        "Downarrow" : MTMathAtom(type: .relation, value: "\u{21D3}"),
        "Leftrightarrow" : MTMathAtom(type: .relation, value: "\u{21D4}"),
        "Updownarrow" : MTMathAtom(type: .relation, value: "\u{21D5}"),
        "longleftarrow" : MTMathAtom(type: .relation, value: "\u{27F5}"),
        "longrightarrow" : MTMathAtom(type: .relation, value: "\u{27F6}"),
        "longleftrightarrow" : MTMathAtom(type: .relation, value: "\u{27F7}"),
        "Longleftarrow" : MTMathAtom(type: .relation, value: "\u{27F8}"),
        "Longrightarrow" : MTMathAtom(type: .relation, value: "\u{27F9}"),
        "Longleftrightarrow" : MTMathAtom(type: .relation, value: "\u{27FA}"),
        "longmapsto" : MTMathAtom(type: .relation, value: "\u{27FC}"),
        "hookrightarrow" : MTMathAtom(type: .relation, value: "\u{21AA}"),
        "hookleftarrow" : MTMathAtom(type: .relation, value: "\u{21A9}"),


        // Relations
        "leq" : MTMathAtom(type: .relation, value: UnicodeSymbol.lessEqual),
        "geq" : MTMathAtom(type: .relation, value: UnicodeSymbol.greaterEqual),
        "leqslant" : MTMathAtom(type: .relation, value: "\u{2A7D}"),
        "geqslant" : MTMathAtom(type: .relation, value: "\u{2A7E}"),
        "neq" : MTMathAtom(type: .relation, value: UnicodeSymbol.notEqual),
        "in" : MTMathAtom(type: .relation, value: "\u{2208}"),
        "notin" : MTMathAtom(type: .relation, value: "\u{2209}"),
        "ni" : MTMathAtom(type: .relation, value: "\u{220B}"),
        "propto" : MTMathAtom(type: .relation, value: "\u{221D}"),
        "mid" : MTMathAtom(type: .relation, value: "\u{2223}"),
        "parallel" : MTMathAtom(type: .relation, value: "\u{2225}"),
        "sim" : MTMathAtom(type: .relation, value: "\u{223C}"),
        "simeq" : MTMathAtom(type: .relation, value: "\u{2243}"),
        "cong" : MTMathAtom(type: .relation, value: "\u{2245}"),
        "approx" : MTMathAtom(type: .relation, value: "\u{2248}"),
        "asymp" : MTMathAtom(type: .relation, value: "\u{224D}"),
        "doteq" : MTMathAtom(type: .relation, value: "\u{2250}"),
        "equiv" : MTMathAtom(type: .relation, value: "\u{2261}"),
        "gg" : MTMathAtom(type: .relation, value: "\u{226B}"),
        "ll" : MTMathAtom(type: .relation, value: "\u{226A}"),
        "prec" : MTMathAtom(type: .relation, value: "\u{227A}"),
        "succ" : MTMathAtom(type: .relation, value: "\u{227B}"),
        "preceq" : MTMathAtom(type: .relation, value: "\u{2AAF}"),
        "succeq" : MTMathAtom(type: .relation, value: "\u{2AB0}"),
        "subset" : MTMathAtom(type: .relation, value: "\u{2282}"),
        "supset" : MTMathAtom(type: .relation, value: "\u{2283}"),
        "subseteq" : MTMathAtom(type: .relation, value: "\u{2286}"),
        "supseteq" : MTMathAtom(type: .relation, value: "\u{2287}"),
        "sqsubset" : MTMathAtom(type: .relation, value: "\u{228F}"),
        "sqsupset" : MTMathAtom(type: .relation, value: "\u{2290}"),
        "sqsubseteq" : MTMathAtom(type: .relation, value: "\u{2291}"),
        "sqsupseteq" : MTMathAtom(type: .relation, value: "\u{2292}"),
        "models" : MTMathAtom(type: .relation, value: "\u{22A7}"),
        "vdash" : MTMathAtom(type: .relation, value: "\u{22A2}"),
        "dashv" : MTMathAtom(type: .relation, value: "\u{22A3}"),
        "bowtie" : MTMathAtom(type: .relation, value: "\u{22C8}"),
        "perp" : MTMathAtom(type: .relation, value: "\u{27C2}"),
        "implies" : MTMathAtom(type: .relation, value: "\u{27F9}"),

        // Negated relations (amssymb)
        // Inequality negations
        "nless" : MTMathAtom(type: .relation, value: "\u{226E}"),
        "ngtr" : MTMathAtom(type: .relation, value: "\u{226F}"),
        "nleq" : MTMathAtom(type: .relation, value: "\u{2270}"),
        "ngeq" : MTMathAtom(type: .relation, value: "\u{2271}"),
        "nleqslant" : MTMathAtom(type: .relation, value: "\u{2A87}"),
        "ngeqslant" : MTMathAtom(type: .relation, value: "\u{2A88}"),
        "lneq" : MTMathAtom(type: .relation, value: "\u{2A87}"),
        "gneq" : MTMathAtom(type: .relation, value: "\u{2A88}"),
        "lneqq" : MTMathAtom(type: .relation, value: "\u{2268}"),
        "gneqq" : MTMathAtom(type: .relation, value: "\u{2269}"),
        "lnsim" : MTMathAtom(type: .relation, value: "\u{22E6}"),
        "gnsim" : MTMathAtom(type: .relation, value: "\u{22E7}"),
        "lnapprox" : MTMathAtom(type: .relation, value: "\u{2A89}"),
        "gnapprox" : MTMathAtom(type: .relation, value: "\u{2A8A}"),

        // Ordering negations
        "nprec" : MTMathAtom(type: .relation, value: "\u{2280}"),
        "nsucc" : MTMathAtom(type: .relation, value: "\u{2281}"),
        "npreceq" : MTMathAtom(type: .relation, value: "\u{22E0}"),
        "nsucceq" : MTMathAtom(type: .relation, value: "\u{22E1}"),
        "precneqq" : MTMathAtom(type: .relation, value: "\u{2AB5}"),
        "succneqq" : MTMathAtom(type: .relation, value: "\u{2AB6}"),
        "precnsim" : MTMathAtom(type: .relation, value: "\u{22E8}"),
        "succnsim" : MTMathAtom(type: .relation, value: "\u{22E9}"),
        "precnapprox" : MTMathAtom(type: .relation, value: "\u{2AB9}"),
        "succnapprox" : MTMathAtom(type: .relation, value: "\u{2ABA}"),

        // Similarity/congruence negations
        "nsim" : MTMathAtom(type: .relation, value: "\u{2241}"),
        "ncong" : MTMathAtom(type: .relation, value: "\u{2247}"),
        "nmid" : MTMathAtom(type: .relation, value: "\u{2224}"),
        "nshortmid" : MTMathAtom(type: .relation, value: "\u{2224}"),
        "nparallel" : MTMathAtom(type: .relation, value: "\u{2226}"),
        "nshortparallel" : MTMathAtom(type: .relation, value: "\u{2226}"),

        // Set relation negations
        "nsubseteq" : MTMathAtom(type: .relation, value: "\u{2288}"),
        "nsupseteq" : MTMathAtom(type: .relation, value: "\u{2289}"),
        "subsetneq" : MTMathAtom(type: .relation, value: "\u{228A}"),
        "supsetneq" : MTMathAtom(type: .relation, value: "\u{228B}"),
        "subsetneqq" : MTMathAtom(type: .relation, value: "\u{2ACB}"),
        "supsetneqq" : MTMathAtom(type: .relation, value: "\u{2ACC}"),
        "varsubsetneq" : MTMathAtom(type: .relation, value: "\u{228A}"),
        "varsupsetneq" : MTMathAtom(type: .relation, value: "\u{228B}"),
        "varsubsetneqq" : MTMathAtom(type: .relation, value: "\u{2ACB}"),
        "varsupsetneqq" : MTMathAtom(type: .relation, value: "\u{2ACC}"),
        "notni" : MTMathAtom(type: .relation, value: "\u{220C}"),
        "nni" : MTMathAtom(type: .relation, value: "\u{220C}"),

        // Triangle negations
        "ntriangleleft" : MTMathAtom(type: .relation, value: "\u{22EA}"),
        "ntriangleright" : MTMathAtom(type: .relation, value: "\u{22EB}"),
        "ntrianglelefteq" : MTMathAtom(type: .relation, value: "\u{22EC}"),
        "ntrianglerighteq" : MTMathAtom(type: .relation, value: "\u{22ED}"),

        // Turnstile negations
        "nvdash" : MTMathAtom(type: .relation, value: "\u{22AC}"),
        "nvDash" : MTMathAtom(type: .relation, value: "\u{22AD}"),
        "nVdash" : MTMathAtom(type: .relation, value: "\u{22AE}"),
        "nVDash" : MTMathAtom(type: .relation, value: "\u{22AF}"),

        // Square subset negations
        "nsqsubseteq" : MTMathAtom(type: .relation, value: "\u{22E2}"),
        "nsqsupseteq" : MTMathAtom(type: .relation, value: "\u{22E3}"),

        // operators
        "times" : MTMathAtomFactory.times(),
        "div"   : MTMathAtomFactory.divide(),
        "pm"    : MTMathAtom(type: .binaryOperator, value: "\u{00B1}"),
        "dagger" : MTMathAtom(type: .binaryOperator, value: "\u{2020}"),
        "ddagger" : MTMathAtom(type: .binaryOperator, value: "\u{2021}"),
        "mp"    : MTMathAtom(type: .binaryOperator, value: "\u{2213}"),
        "setminus" : MTMathAtom(type: .binaryOperator, value: "\u{2216}"),
        "ast"   : MTMathAtom(type: .binaryOperator, value: "\u{2217}"),
        "circ"  : MTMathAtom(type: .binaryOperator, value: "\u{2218}"),
        "bullet" : MTMathAtom(type: .binaryOperator, value: "\u{2219}"),
        "wedge" : MTMathAtom(type: .binaryOperator, value: "\u{2227}"),
        "vee" : MTMathAtom(type: .binaryOperator, value: "\u{2228}"),
        "cap" : MTMathAtom(type: .binaryOperator, value: "\u{2229}"),
        "cup" : MTMathAtom(type: .binaryOperator, value: "\u{222A}"),
        "wr" : MTMathAtom(type: .binaryOperator, value: "\u{2240}"),
        "uplus" : MTMathAtom(type: .binaryOperator, value: "\u{228E}"),
        "sqcap" : MTMathAtom(type: .binaryOperator, value: "\u{2293}"),
        "sqcup" : MTMathAtom(type: .binaryOperator, value: "\u{2294}"),
        "oplus" : MTMathAtom(type: .binaryOperator, value: "\u{2295}"),
        "ominus" : MTMathAtom(type: .binaryOperator, value: "\u{2296}"),
        "otimes" : MTMathAtom(type: .binaryOperator, value: "\u{2297}"),
        "oslash" : MTMathAtom(type: .binaryOperator, value: "\u{2298}"),
        "odot" : MTMathAtom(type: .binaryOperator, value: "\u{2299}"),
        "star"  : MTMathAtom(type: .binaryOperator, value: "\u{22C6}"),
        "cdot"  : MTMathAtom(type: .binaryOperator, value: "\u{22C5}"),
        "diamond" : MTMathAtom(type: .binaryOperator, value: "\u{22C4}"),
        "amalg" : MTMathAtom(type: .binaryOperator, value: "\u{2A3F}"),

        // Additional binary operators (amssymb)
        "ltimes" : MTMathAtom(type: .binaryOperator, value: "\u{22C9}"),  // left semidirect product
        "rtimes" : MTMathAtom(type: .binaryOperator, value: "\u{22CA}"),  // right semidirect product
        "circledast" : MTMathAtom(type: .binaryOperator, value: "\u{229B}"),
        "circledcirc" : MTMathAtom(type: .binaryOperator, value: "\u{229A}"),
        "circleddash" : MTMathAtom(type: .binaryOperator, value: "\u{229D}"),
        "boxdot" : MTMathAtom(type: .binaryOperator, value: "\u{22A1}"),
        "boxminus" : MTMathAtom(type: .binaryOperator, value: "\u{229F}"),
        "boxplus" : MTMathAtom(type: .binaryOperator, value: "\u{229E}"),
        "boxtimes" : MTMathAtom(type: .binaryOperator, value: "\u{22A0}"),
        "divideontimes" : MTMathAtom(type: .binaryOperator, value: "\u{22C7}"),
        "dotplus" : MTMathAtom(type: .binaryOperator, value: "\u{2214}"),
        "lhd" : MTMathAtom(type: .binaryOperator, value: "\u{22B2}"),  // left normal subgroup
        "rhd" : MTMathAtom(type: .binaryOperator, value: "\u{22B3}"),  // right normal subgroup
        "unlhd" : MTMathAtom(type: .binaryOperator, value: "\u{22B4}"),  // left normal subgroup or equal
        "unrhd" : MTMathAtom(type: .binaryOperator, value: "\u{22B5}"),  // right normal subgroup or equal
        "intercal" : MTMathAtom(type: .binaryOperator, value: "\u{22BA}"),
        "barwedge" : MTMathAtom(type: .binaryOperator, value: "\u{22BC}"),
        "veebar" : MTMathAtom(type: .binaryOperator, value: "\u{22BB}"),
        "curlywedge" : MTMathAtom(type: .binaryOperator, value: "\u{22CF}"),
        "curlyvee" : MTMathAtom(type: .binaryOperator, value: "\u{22CE}"),
        "doublebarwedge" : MTMathAtom(type: .binaryOperator, value: "\u{2A5E}"),
        "centerdot" : MTMathAtom(type: .binaryOperator, value: "\u{22C5}"),  // alias for cdot

        // No limit operators
        "log" : MTMathAtomFactory.operatorWithName( "log", limits: false),
        "lg" : MTMathAtomFactory.operatorWithName( "lg", limits: false),
        "ln" : MTMathAtomFactory.operatorWithName( "ln", limits: false),
        "sin" : MTMathAtomFactory.operatorWithName( "sin", limits: false),
        "arcsin" : MTMathAtomFactory.operatorWithName( "arcsin", limits: false),
        "sinh" : MTMathAtomFactory.operatorWithName( "sinh", limits: false),
        "cos" : MTMathAtomFactory.operatorWithName( "cos", limits: false),
        "arccos" : MTMathAtomFactory.operatorWithName( "arccos", limits: false),
        "cosh" : MTMathAtomFactory.operatorWithName( "cosh", limits: false),
        "tan" : MTMathAtomFactory.operatorWithName( "tan", limits: false),
        "arctan" : MTMathAtomFactory.operatorWithName( "arctan", limits: false),
        "tanh" : MTMathAtomFactory.operatorWithName( "tanh", limits: false),
        "cot" : MTMathAtomFactory.operatorWithName( "cot", limits: false),
        "coth" : MTMathAtomFactory.operatorWithName( "coth", limits: false),
        "sec" : MTMathAtomFactory.operatorWithName( "sec", limits: false),
        "csc" : MTMathAtomFactory.operatorWithName( "csc", limits: false),
        // Additional inverse trig functions
        "arccot" : MTMathAtomFactory.operatorWithName( "arccot", limits: false),
        "arcsec" : MTMathAtomFactory.operatorWithName( "arcsec", limits: false),
        "arccsc" : MTMathAtomFactory.operatorWithName( "arccsc", limits: false),
        // Additional hyperbolic functions
        "sech" : MTMathAtomFactory.operatorWithName( "sech", limits: false),
        "csch" : MTMathAtomFactory.operatorWithName( "csch", limits: false),
        // Inverse hyperbolic functions
        "arcsinh" : MTMathAtomFactory.operatorWithName( "arcsinh", limits: false),
        "arccosh" : MTMathAtomFactory.operatorWithName( "arccosh", limits: false),
        "arctanh" : MTMathAtomFactory.operatorWithName( "arctanh", limits: false),
        "arccoth" : MTMathAtomFactory.operatorWithName( "arccoth", limits: false),
        "arcsech" : MTMathAtomFactory.operatorWithName( "arcsech", limits: false),
        "arccsch" : MTMathAtomFactory.operatorWithName( "arccsch", limits: false),
        "arg" : MTMathAtomFactory.operatorWithName( "arg", limits: false),
        "ker" : MTMathAtomFactory.operatorWithName( "ker", limits: false),
        "dim" : MTMathAtomFactory.operatorWithName( "dim", limits: false),
        "hom" : MTMathAtomFactory.operatorWithName( "hom", limits: false),
        "exp" : MTMathAtomFactory.operatorWithName( "exp", limits: false),
        "deg" : MTMathAtomFactory.operatorWithName( "deg", limits: false),
        "mod" : MTMathAtomFactory.operatorWithName("mod", limits: false),

        // Limit operators
        "lim" : MTMathAtomFactory.operatorWithName( "lim", limits: true),
        "limsup" : MTMathAtomFactory.operatorWithName( "lim sup", limits: true),
        "liminf" : MTMathAtomFactory.operatorWithName( "lim inf", limits: true),
        "max" : MTMathAtomFactory.operatorWithName( "max", limits: true),
        "min" : MTMathAtomFactory.operatorWithName( "min", limits: true),
        "sup" : MTMathAtomFactory.operatorWithName( "sup", limits: true),
        "inf" : MTMathAtomFactory.operatorWithName( "inf", limits: true),
        "det" : MTMathAtomFactory.operatorWithName( "det", limits: true),
        "Pr" : MTMathAtomFactory.operatorWithName( "Pr", limits: true),
        "gcd" : MTMathAtomFactory.operatorWithName( "gcd", limits: true),

        // Large operators
        "prod" : MTMathAtomFactory.operatorWithName( "\u{220F}", limits: true),
        "coprod" : MTMathAtomFactory.operatorWithName( "\u{2210}", limits: true),
        "sum" : MTMathAtomFactory.operatorWithName( "\u{2211}", limits: true),
        "int" : MTMathAtomFactory.operatorWithName( "\u{222B}", limits: false),
        "iint" : MTMathAtomFactory.operatorWithName( "\u{222C}", limits: false),
        "iiint" : MTMathAtomFactory.operatorWithName( "\u{222D}", limits: false),
        "iiiint" : MTMathAtomFactory.operatorWithName( "\u{2A0C}", limits: false),
        "oint" : MTMathAtomFactory.operatorWithName( "\u{222E}", limits: false),
        "bigwedge" : MTMathAtomFactory.operatorWithName( "\u{22C0}", limits: true),
        "bigvee" : MTMathAtomFactory.operatorWithName( "\u{22C1}", limits: true),
        "bigcap" : MTMathAtomFactory.operatorWithName( "\u{22C2}", limits: true),
        "bigcup" : MTMathAtomFactory.operatorWithName( "\u{22C3}", limits: true),
        "bigodot" : MTMathAtomFactory.operatorWithName( "\u{2A00}", limits: true),
        "bigoplus" : MTMathAtomFactory.operatorWithName( "\u{2A01}", limits: true),
        "bigotimes" : MTMathAtomFactory.operatorWithName( "\u{2A02}", limits: true),
        "biguplus" : MTMathAtomFactory.operatorWithName( "\u{2A04}", limits: true),
        "bigsqcup" : MTMathAtomFactory.operatorWithName( "\u{2A06}", limits: true),

        // Latex command characters
        "{" : MTMathAtom(type: .open, value: "{"),
        "}" : MTMathAtom(type: .close, value: "}"),
        "$" : MTMathAtom(type: .ordinary, value: "$"),
        "&" : MTMathAtom(type: .ordinary, value: "&"),
        "#" : MTMathAtom(type: .ordinary, value: "#"),
        "%" : MTMathAtom(type: .ordinary, value: "%"),
        "_" : MTMathAtom(type: .ordinary, value: "_"),
        " " : MTMathAtom(type: .ordinary, value: " "),
        "backslash" : MTMathAtom(type: .ordinary, value: "\\"),

        // Punctuation
        // Note: \colon is different from : which is a relation
        "colon" : MTMathAtom(type: .punctuation, value: ":"),
        "cdotp" : MTMathAtom(type: .punctuation, value: "\u{00B7}"),

        // Other symbols
        "degree" : MTMathAtom(type: .ordinary, value: "\u{00B0}"),
        "neg" : MTMathAtom(type: .ordinary, value: "\u{00AC}"),
        "angstrom" : MTMathAtom(type: .ordinary, value: "\u{00C5}"),
		"aa" : MTMathAtom(type: .ordinary, value: "\u{00E5}"),	// NEW å
		"ae" : MTMathAtom(type: .ordinary, value: "\u{00E6}"),	// NEW æ
		"o"  : MTMathAtom(type: .ordinary, value: "\u{00F8}"),	// NEW ø
		"oe" : MTMathAtom(type: .ordinary, value: "\u{0153}"),	// NEW œ
		"ss" : MTMathAtom(type: .ordinary, value: "\u{00DF}"),	// NEW ß
		"cc" : MTMathAtom(type: .ordinary, value: "\u{00E7}"),	// NEW ç
		"CC" : MTMathAtom(type: .ordinary, value: "\u{00C7}"),	// NEW Ç
		"O"  : MTMathAtom(type: .ordinary, value: "\u{00D8}"),	// NEW Ø
		"AE" : MTMathAtom(type: .ordinary, value: "\u{00C6}"),	// NEW Æ
		"OE" : MTMathAtom(type: .ordinary, value: "\u{0152}"),	// NEW Œ
        "|" : MTMathAtom(type: .ordinary, value: "\u{2016}"),
        "vert" : MTMathAtom(type: .ordinary, value: "|"),
        "ldots" : MTMathAtom(type: .ordinary, value: "\u{2026}"),
        "prime" : MTMathAtom(type: .ordinary, value: "\u{2032}"),
        // \left 없이 홀로 쓰는 노름 기호. \lVert 는 별칭이 Vert 로 풀리는데 Vert 가
        // 구분자 표에만 있어서 "미지원 명령"이 됐다. 별칭이 닿을 곳을 만들어 준다.
        "Vert" : MTMathAtom(type: .ordinary, value: "\u{2016}"),
        // 천분율 — 화학·환경공학 농도 표기에 나온다.
        "permil" : MTMathAtom(type: .ordinary, value: "\u{2030}"),
        "perthousand" : MTMathAtom(type: .ordinary, value: "\u{2030}"),
        "hbar" : MTMathAtom(type: .ordinary, value: "\u{210F}"),
        "lbar" : MTMathAtom(type: .ordinary, value: "\u{019B}"),  // NEW ƛ
        "Im" : MTMathAtom(type: .ordinary, value: "\u{2111}"),
        "ell" : MTMathAtom(type: .ordinary, value: "\u{2113}"),
        "wp" : MTMathAtom(type: .ordinary, value: "\u{2118}"),
        "Re" : MTMathAtom(type: .ordinary, value: "\u{211C}"),
        "mho" : MTMathAtom(type: .ordinary, value: "\u{2127}"),
        "aleph" : MTMathAtom(type: .ordinary, value: "\u{2135}"),
        "beth" : MTMathAtom(type: .ordinary, value: "\u{2136}"),
        "gimel" : MTMathAtom(type: .ordinary, value: "\u{2137}"),
        "daleth" : MTMathAtom(type: .ordinary, value: "\u{2138}"),
        "forall" : MTMathAtom(type: .ordinary, value: "\u{2200}"),
        "exists" : MTMathAtom(type: .ordinary, value: "\u{2203}"),
        "nexists" : MTMathAtom(type: .ordinary, value: "\u{2204}"),
        "emptyset" : MTMathAtom(type: .ordinary, value: "\u{2205}"),
        "varnothing" : MTMathAtom(type: .ordinary, value: "\u{2205}"),
        "nabla" : MTMathAtom(type: .ordinary, value: "\u{2207}"),
        "infty" : MTMathAtom(type: .ordinary, value: "\u{221E}"),
        "angle" : MTMathAtom(type: .ordinary, value: "\u{2220}"),
        "measuredangle" : MTMathAtom(type: .ordinary, value: "\u{2221}"),
        "top" : MTMathAtom(type: .ordinary, value: "\u{22A4}"),
        "bot" : MTMathAtom(type: .ordinary, value: "\u{22A5}"),
        "vdots" : MTMathAtom(type: .ordinary, value: "\u{22EE}"),
        "cdots" : MTMathAtom(type: .ordinary, value: "\u{22EF}"),
        "ddots" : MTMathAtom(type: .ordinary, value: "\u{22F1}"),
        "triangle" : MTMathAtom(type: .ordinary, value: "\u{25B3}"),
        "Box" : MTMathAtom(type: .ordinary, value: "\u{25A1}"),
        "imath" : MTMathAtom(type: .ordinary, value: "\u{0001D6A4}"),
        "jmath" : MTMathAtom(type: .ordinary, value: "\u{0001D6A5}"),
        "upquote" : MTMathAtom(type: .ordinary, value: "\u{0027}"),
        "partial" : MTMathAtom(type: .ordinary, value: "\u{0001D715}"),

        // Spacing
        "," : MTMathSpace(space: 3),
        ">" : MTMathSpace(space: 4),
        ":" : MTMathSpace(space: 4),   // \: medium space
        ";" : MTMathSpace(space: 5),
        "!" : MTMathSpace(space: -3),
        "quad" : MTMathSpace(space: 18),  // quad = 1em = 18mu
        "qquad" : MTMathSpace(space: 36), // qquad = 2em

        // ── amsmath/amssymb 확장 (2026-07-26) ────────────────────────────────────────
        // 추가 원칙: latinmodern-math 에 글리프가 **실재하는** 코드포인트만 넣는다.
        // 없는 코드포인트를 넣으면 파싱은 성공하고 CoreText가 시스템 CJK 폰트로 대체해
        // 전각(1em) 글리프를 그린다 — 실패가 아니라 조용한 오조판이 된다.
        // GlyphCoverageTests 가 이 규칙을 강제한다.

        // 관계자
        "therefore" : MTMathAtom(type: .relation, value: "\u{2234}"),
        "because" : MTMathAtom(type: .relation, value: "\u{2235}"),
        "lesssim" : MTMathAtom(type: .relation, value: "\u{2272}"),
        "gtrsim" : MTMathAtom(type: .relation, value: "\u{2273}"),
        "leqq" : MTMathAtom(type: .relation, value: "\u{2266}"),
        "geqq" : MTMathAtom(type: .relation, value: "\u{2267}"),
        "vDash" : MTMathAtom(type: .relation, value: "\u{22A8}"),
        "Vdash" : MTMathAtom(type: .relation, value: "\u{22A9}"),
        "Vvdash" : MTMathAtom(type: .relation, value: "\u{22AA}"),
        "preccurlyeq" : MTMathAtom(type: .relation, value: "\u{227C}"),
        "succcurlyeq" : MTMathAtom(type: .relation, value: "\u{227D}"),
        "precsim" : MTMathAtom(type: .relation, value: "\u{227E}"),
        "succsim" : MTMathAtom(type: .relation, value: "\u{227F}"),
        "triangleq" : MTMathAtom(type: .relation, value: "\u{225C}"),
        "coloneqq" : MTMathAtom(type: .relation, value: "\u{2254}"),
        "eqqcolon" : MTMathAtom(type: .relation, value: "\u{2255}"),
        "Doteq" : MTMathAtom(type: .relation, value: "\u{2251}"),
        "approxeq" : MTMathAtom(type: .relation, value: "\u{224A}"),
        "eqsim" : MTMathAtom(type: .relation, value: "\u{2242}"),
        "backsim" : MTMathAtom(type: .relation, value: "\u{223D}"),
        "circeq" : MTMathAtom(type: .relation, value: "\u{2257}"),
        "bumpeq" : MTMathAtom(type: .relation, value: "\u{224F}"),
        "Bumpeq" : MTMathAtom(type: .relation, value: "\u{224E}"),
        "Subset" : MTMathAtom(type: .relation, value: "\u{22D0}"),
        "Supset" : MTMathAtom(type: .relation, value: "\u{22D1}"),
        "multimap" : MTMathAtom(type: .relation, value: "\u{22B8}"),
        "between" : MTMathAtom(type: .relation, value: "\u{226C}"),
        "gtrless" : MTMathAtom(type: .relation, value: "\u{2277}"),
        "lessgtr" : MTMathAtom(type: .relation, value: "\u{2276}"),
        "lessdot" : MTMathAtom(type: .relation, value: "\u{22D6}"),
        "gtrdot" : MTMathAtom(type: .relation, value: "\u{22D7}"),
        "lll" : MTMathAtom(type: .relation, value: "\u{22D8}"),
        "ggg" : MTMathAtom(type: .relation, value: "\u{22D9}"),
        "trianglelefteq" : MTMathAtom(type: .relation, value: "\u{22B4}"),
        "trianglerighteq" : MTMathAtom(type: .relation, value: "\u{22B5}"),
        "frown" : MTMathAtom(type: .relation, value: "\u{2322}"),
        "smile" : MTMathAtom(type: .relation, value: "\u{2323}"),
        "vcentcolon" : MTMathAtom(type: .relation, value: "\u{2236}"),
        "ratio" : MTMathAtom(type: .relation, value: "\u{2236}"),

        // 화살표 관계자 — 화학 평형(rightleftharpoons)·사상 표기에 자주 쓰인다.
        "rightleftharpoons" : MTMathAtom(type: .relation, value: "\u{21CC}"),
        "leftrightharpoons" : MTMathAtom(type: .relation, value: "\u{21CB}"),
        "leftharpoonup" : MTMathAtom(type: .relation, value: "\u{21BC}"),
        "leftharpoondown" : MTMathAtom(type: .relation, value: "\u{21BD}"),
        "rightharpoonup" : MTMathAtom(type: .relation, value: "\u{21C0}"),
        "rightharpoondown" : MTMathAtom(type: .relation, value: "\u{21C1}"),
        "upharpoonright" : MTMathAtom(type: .relation, value: "\u{21BE}"),
        "upharpoonleft" : MTMathAtom(type: .relation, value: "\u{21BF}"),
        "downharpoonright" : MTMathAtom(type: .relation, value: "\u{21C2}"),
        "downharpoonleft" : MTMathAtom(type: .relation, value: "\u{21C3}"),
        "twoheadrightarrow" : MTMathAtom(type: .relation, value: "\u{21A0}"),
        "twoheadleftarrow" : MTMathAtom(type: .relation, value: "\u{219E}"),
        "rightsquigarrow" : MTMathAtom(type: .relation, value: "\u{21DD}"),
        "nleftarrow" : MTMathAtom(type: .relation, value: "\u{219A}"),
        "nrightarrow" : MTMathAtom(type: .relation, value: "\u{219B}"),
        "curvearrowleft" : MTMathAtom(type: .relation, value: "\u{21B6}"),
        "curvearrowright" : MTMathAtom(type: .relation, value: "\u{21B7}"),
        "circlearrowleft" : MTMathAtom(type: .relation, value: "\u{21BA}"),
        "circlearrowright" : MTMathAtom(type: .relation, value: "\u{21BB}"),
        "leftrightarrows" : MTMathAtom(type: .relation, value: "\u{21C6}"),
        "rightleftarrows" : MTMathAtom(type: .relation, value: "\u{21C4}"),
        "leftleftarrows" : MTMathAtom(type: .relation, value: "\u{21C7}"),
        "rightrightarrows" : MTMathAtom(type: .relation, value: "\u{21C9}"),
        "upuparrows" : MTMathAtom(type: .relation, value: "\u{21C8}"),
        "downdownarrows" : MTMathAtom(type: .relation, value: "\u{21CA}"),
        "leftarrowtail" : MTMathAtom(type: .relation, value: "\u{21A2}"),
        "rightarrowtail" : MTMathAtom(type: .relation, value: "\u{21A3}"),

        // 이항 연산자
        // ※ triangleleft/right 는 U+25C1/25B7 이다. U+25C3/25B9(작은 삼각형)는
        //   latinmodern 이 갖고 있지 않아 CJK 폰트 전각으로 떨어진다.
        "bigcirc" : MTMathAtom(type: .binaryOperator, value: "\u{25EF}"),
        "Cap" : MTMathAtom(type: .binaryOperator, value: "\u{22D2}"),
        "Cup" : MTMathAtom(type: .binaryOperator, value: "\u{22D3}"),
        "leftthreetimes" : MTMathAtom(type: .binaryOperator, value: "\u{22CB}"),
        "rightthreetimes" : MTMathAtom(type: .binaryOperator, value: "\u{22CC}"),
        "triangleleft" : MTMathAtom(type: .binaryOperator, value: "\u{25C1}"),
        "triangleright" : MTMathAtom(type: .binaryOperator, value: "\u{25B7}"),

        // 일반 기호
        "blacksquare" : MTMathAtom(type: .ordinary, value: "\u{25A0}"),
        "checkmark" : MTMathAtom(type: .ordinary, value: "\u{2713}"),
        "blacktriangle" : MTMathAtom(type: .ordinary, value: "\u{25B2}"),
        "blacktriangledown" : MTMathAtom(type: .ordinary, value: "\u{25BC}"),
        "blacktriangleleft" : MTMathAtom(type: .ordinary, value: "\u{25C0}"),
        "blacktriangleright" : MTMathAtom(type: .ordinary, value: "\u{25B6}"),
        "triangledown" : MTMathAtom(type: .ordinary, value: "\u{25BD}"),
        "Diamond" : MTMathAtom(type: .ordinary, value: "\u{25CA}"),
        "complement" : MTMathAtom(type: .ordinary, value: "\u{2201}"),
        "sphericalangle" : MTMathAtom(type: .ordinary, value: "\u{2222}"),
        "backprime" : MTMathAtom(type: .ordinary, value: "\u{2035}"),
        "natural" : MTMathAtom(type: .ordinary, value: "\u{266E}"),
        "flat" : MTMathAtom(type: .ordinary, value: "\u{266D}"),
        "sharp" : MTMathAtom(type: .ordinary, value: "\u{266F}"),
        "dag" : MTMathAtom(type: .ordinary, value: "\u{2020}"),
        "ddag" : MTMathAtom(type: .ordinary, value: "\u{2021}"),
        "circledR" : MTMathAtom(type: .ordinary, value: "\u{00AE}"),
        "copyright" : MTMathAtom(type: .ordinary, value: "\u{00A9}"),
        "mathsterling" : MTMathAtom(type: .ordinary, value: "\u{00A3}"),
        "yen" : MTMathAtom(type: .ordinary, value: "\u{00A5}"),
        "P" : MTMathAtom(type: .ordinary, value: "\u{00B6}"),
        "S" : MTMathAtom(type: .ordinary, value: "\u{00A7}"),
        "surd" : MTMathAtom(type: .ordinary, value: "\u{221A}"),
        "eth" : MTMathAtom(type: .ordinary, value: "\u{00F0}"),
        "smallint" : MTMathAtom(type: .ordinary, value: "\u{222B}"),
        "clubsuit" : MTMathAtom(type: .ordinary, value: "\u{2663}"),
        "diamondsuit" : MTMathAtom(type: .ordinary, value: "\u{2662}"),
        "heartsuit" : MTMathAtom(type: .ordinary, value: "\u{2661}"),
        "spadesuit" : MTMathAtom(type: .ordinary, value: "\u{2660}"),

        // 대문자 그리스 — 기존 \Gamma 계열과 같은 .variable 로 둔다(조판기가 대문자
        // 그리스를 upright 로 처리하므로 스타일이 일관된다).
        "Alpha" : MTMathAtom(type: .variable, value: "\u{0391}"),
        "Beta" : MTMathAtom(type: .variable, value: "\u{0392}"),
        "Epsilon" : MTMathAtom(type: .variable, value: "\u{0395}"),
        "Zeta" : MTMathAtom(type: .variable, value: "\u{0396}"),
        "Eta" : MTMathAtom(type: .variable, value: "\u{0397}"),
        "Iota" : MTMathAtom(type: .variable, value: "\u{0399}"),
        "Kappa" : MTMathAtom(type: .variable, value: "\u{039A}"),
        "Mu" : MTMathAtom(type: .variable, value: "\u{039C}"),
        "Nu" : MTMathAtom(type: .variable, value: "\u{039D}"),
        "Omicron" : MTMathAtom(type: .variable, value: "\u{039F}"),
        "Rho" : MTMathAtom(type: .variable, value: "\u{03A1}"),
        "Tau" : MTMathAtom(type: .variable, value: "\u{03A4}"),
        "Chi" : MTMathAtom(type: .variable, value: "\u{03A7}"),

        // 이름 있는 공백 — 폭은 measureSpace 가 MTMathSpace.space(mu)에서 읽는다.
        "thinspace" : MTMathSpace(space: 3),
        "medspace" : MTMathSpace(space: 4),
        "thickspace" : MTMathSpace(space: 5),
        "negthinspace" : MTMathSpace(space: -3),
        "negmedspace" : MTMathSpace(space: -4),
        "negthickspace" : MTMathSpace(space: -5),
        "nobreakspace" : MTMathSpace(space: 6),
        "space" : MTMathSpace(space: 6),
        "enspace" : MTMathSpace(space: 9),

        // 이름 있는 연산자
        // 알려진 한계: \bmod 는 TeX에서 이항 연산자라 양옆에 간격이 붙어야 하는데, 여기서는
        // largeOperator 로 만들어져 간격이 0이다(실측 `a\bmod b`=56.94 vs `amodb`=56.82).
        // 그래도 두는 이유는 없을 때가 더 나쁘기 때문이다 — 미지원이면 호출부의 자가 치유가
        // 명령 토큰을 벗겨 "mod" 라는 **낱말 자체가 사라지고** 수식의 의미가 바뀐다.
        "bmod" : MTMathAtomFactory.operatorWithName("mod", limits: false),
        "argmax" : MTMathAtomFactory.operatorWithName("arg max", limits: true),
        "argmin" : MTMathAtomFactory.operatorWithName("arg min", limits: true),
        "injlim" : MTMathAtomFactory.operatorWithName("inj lim", limits: true),
        "projlim" : MTMathAtomFactory.operatorWithName("proj lim", limits: true),
        "varliminf" : MTMathAtomFactory.operatorWithName("lim inf", limits: true),
        "varlimsup" : MTMathAtomFactory.operatorWithName("lim sup", limits: true),
        "plim" : MTMathAtomFactory.operatorWithName("plim", limits: true),
        // 역극한·순극한 — 대수학·위상수학에서 정기적으로 나온다. amsmath 는 lim 아래에
        // 화살표를 붙이지만, 늘어나는 화살표를 아직 못 그리므로 이름으로 구분한다.
        "varprojlim" : MTMathAtomFactory.operatorWithName("proj lim", limits: true),
        "varinjlim" : MTMathAtomFactory.operatorWithName("inj lim", limits: true),
        "cosec" : MTMathAtomFactory.operatorWithName("cosec", limits: false),
        "ch" : MTMathAtomFactory.operatorWithName("ch", limits: false),
        "sh" : MTMathAtomFactory.operatorWithName("sh", limits: false),
        "th" : MTMathAtomFactory.operatorWithName("th", limits: false),
        "tg" : MTMathAtomFactory.operatorWithName("tg", limits: false),
        "ctg" : MTMathAtomFactory.operatorWithName("ctg", limits: false),
        "cth" : MTMathAtomFactory.operatorWithName("cth", limits: false),

        // Style
        "displaystyle" : MTMathStyle(style: .display),
        "textstyle" : MTMathStyle(style: .text),
        "scriptstyle" : MTMathStyle(style: .script),
        "scriptscriptstyle" : MTMathStyle(style: .scriptOfScript),
    ]
	
	static var supportedAccentedCharacters: [Character: (String, String)] = [
		// Acute accents
		"á": ("acute", "a"), "é": ("acute", "e"), "í": ("acute", "i"),
		"ó": ("acute", "o"), "ú": ("acute", "u"), "ý": ("acute", "y"),
		
		// Grave accents
		"à": ("grave", "a"), "è": ("grave", "e"), "ì": ("grave", "i"),
		"ò": ("grave", "o"), "ù": ("grave", "u"),
		
		// Circumflex
		"â": ("hat", "a"), "ê": ("hat", "e"), "î": ("hat", "i"),
		"ĵ": ("hat", "j"),  // j with circumflex (Esperanto)
		"ô": ("hat", "o"), "û": ("hat", "u"),
		
		// Umlaut/dieresis
		"ä": ("ddot", "a"), "ë": ("ddot", "e"), "ï": ("ddot", "i"),
		"ö": ("ddot", "o"), "ü": ("ddot", "u"), "ÿ": ("ddot", "y"),
		
		// Tilde
		"ã": ("tilde", "a"), "ñ": ("tilde", "n"), "õ": ("tilde", "o"),
		
		// Special characters
		"ç": ("cc", ""), "ø": ("o", ""), "å": ("aa", ""), "æ": ("ae", ""),
		"œ": ("oe", ""), "ß": ("ss", ""),
		"'": ("upquote", ""),  // this may be dangerous in math mode
		
		// Upper case variants
		"Á": ("acute", "A"), "É": ("acute", "E"), "Í": ("acute", "I"),
		"Ó": ("acute", "O"), "Ú": ("acute", "U"), "Ý": ("acute", "Y"),
		"À": ("grave", "A"), "È": ("grave", "E"), "Ì": ("grave", "I"),
		"Ò": ("grave", "O"), "Ù": ("grave", "U"),
		"Â": ("hat", "A"), "Ê": ("hat", "E"), "Î": ("hat", "I"),
		"Ô": ("hat", "O"), "Û": ("hat", "U"),
		"Ä": ("ddot", "A"), "Ë": ("ddot", "E"), "Ï": ("ddot", "I"),
		"Ö": ("ddot", "O"), "Ü": ("ddot", "U"),
		"Ã": ("tilde", "A"), "Ñ": ("tilde", "N"), "Õ": ("tilde", "O"),
		"Ç": ("CC", ""),
		"Ø": ("O", ""),
		"Å": ("AA", ""),
		"Æ": ("AE", ""),
		"Œ": ("OE", ""),
	]
    
    private static let textToLatexLock = NSLock()
    static var _textToLatexSymbolName: [String: String]? = nil
    public static var textToLatexSymbolName: [String: String] {
        get {
            if self._textToLatexSymbolName == nil {
                var output = [String: String]()
                for (key, atom) in Self.supportedLatexSymbols {
                    if atom.nucleus.count == 0 {
                        continue
                    }
                    if let existingText = output[atom.nucleus] {
                        // If there are 2 key for the same symbol, choose one deterministically.
                        if key.count > existingText.count {
                            // Keep the shorter command
                            continue
                        } else if key.count == existingText.count {
                            // If the length is the same, keep the alphabetically first
                            if key.compare(existingText) == .orderedDescending {
                                continue
                            }
                        }
                    }
                    output[atom.nucleus] = key
                }
                // protect lazily loading table in a multi-thread concurrent environment
                textToLatexLock.lock()
                defer { textToLatexLock.unlock() }
                if self._textToLatexSymbolName == nil {
                    self._textToLatexSymbolName = output
                }
            }
            return self._textToLatexSymbolName!
        }
        // make textToLatexSymbolName readonly (allows internal load)
        // entries can be lazily added with NSLock protection.
        // set {
        //     self._textToLatexSymbolName = newValue
        // }
    }
    
  //  public static let sharedInstance = MTMathAtomFactory()
    
    static let fontStyles : [String: MTFontStyle] = [
        "mathnormal" : .defaultStyle,
        "mathrm": .roman,
        "textrm": .roman,
        "rm": .roman,
        "mathbf": .bold,
        "bf": .bold,
        "textbf": .bold,
        "mathcal": .caligraphic,
        "cal": .caligraphic,
        "mathtt": .typewriter,
        "texttt": .typewriter,
        "mathit": .italic,
        "textit": .italic,
        "mit": .italic,
        "mathsf": .sansSerif,
        "textsf": .sansSerif,
        "mathfrak": .fraktur,
        "frak": .fraktur,
        "mathbb": .blackboard,
        "mathbfit": .boldItalic,
        "bm": .boldItalic,
        "boldsymbol": .boldItalic,
        "text": .roman,
        // Script alphabet. TeX's \mathscr (mathrsfs/unicode-math) is a distinct, more ornate
        // script than \mathcal, but the bundled math fonts expose one script alphabet — mapping
        // it here renders the intended letterform instead of failing the *entire* expression
        // with "Invalid command \mathscr". Physics/EE material uses it constantly (the electric
        // field 𝓔 is the canonical case), so rejecting it is expensive in practice.
        "mathscr": .caligraphic,
        "scr": .caligraphic,
        // Further amsmath/unicode-math spellings that map cleanly onto supported styles.
        "pmb": .boldItalic,
        "mathds": .blackboard,
        "mathsfit": .sansSerif,
        // Note: operatorname is handled specially in MTMathListBuilder to create proper operators
    ]
    
    public static func fontStyleWithName(_ fontName:String) -> MTFontStyle? {
        fontStyles[fontName]
    }
    
    public static func fontNameForStyle(_ fontStyle:MTFontStyle) -> String {
        switch fontStyle {
            case .defaultStyle: return "mathnormal"
            case .roman:        return "mathrm"
            case .bold:         return "mathbf"
            case .fraktur:      return "mathfrak"
            case .caligraphic:  return "mathcal"
            case .italic:       return "mathit"
            case .sansSerif:    return "mathsf"
            case .blackboard:   return "mathbb"
            case .typewriter:   return "mathtt"
            case .boldItalic:   return "bm"
        }
    }
    
    /// Returns an atom for the multiplication sign (i.e., \times or "*")
    public static func times() -> MTMathAtom {
        MTMathAtom(type: .binaryOperator, value: UnicodeSymbol.multiplication)
    }
    
    /// Returns an atom for the division sign (i.e., \div or "/")
    public static func divide() -> MTMathAtom {
        MTMathAtom(type: .binaryOperator, value: UnicodeSymbol.division)
    }
    
    /// Returns an atom which is a placeholder square
    public static func placeholder() -> MTMathAtom {
        MTMathAtom(type: .placeholder, value: UnicodeSymbol.whiteSquare)
    }
    
    /** Returns a fraction with a placeholder for the numerator and denominator */
    public static func placeholderFraction() -> MTFraction {
        let frac = MTFraction()
        frac.numerator = MTMathList()
        frac.numerator?.add(placeholder())
        frac.denominator = MTMathList()
        frac.denominator?.add(placeholder())
        return frac
    }
    
    /** Returns a square root with a placeholder as the radicand. */
    public static func placeholderSquareRoot() -> MTRadical {
        let rad = MTRadical()
        rad.radicand = MTMathList()
        rad.radicand?.add(placeholder())
        return rad
    }
    
    /** Returns a radical with a placeholder as the radicand. */
    public static func placeholderRadical() -> MTRadical {
        let rad = MTRadical()
        rad.radicand = MTMathList()
        rad.degree = MTMathList()
        rad.radicand?.add(placeholder())
        rad.degree?.add(placeholder())
        return rad
    }
	
	/// Latin Small Letter Dotless I (U+0131) - base character that can be styled
	private static let dotlessI: Character = "\u{0131}"
	/// Latin Small Letter Dotless J (U+0237) - base character that can be styled
	private static let dotlessJ: Character = "\u{0237}"

	public static func atom(fromAccentedCharacter ch: Character) -> MTMathAtom? {
		if let symbol = supportedAccentedCharacters[ch] {
			// first handle any special characters
			if let atom = atom(forLatexSymbol: symbol.0) {
				return atom
			}

			if let accent = MTMathAtomFactory.accent(withName: symbol.0) {
				// The command is an accent
				let list = MTMathList()
				let baseChar = Array(symbol.1)[0]
				// Use dotless variants for 'i' and 'j' to avoid double dots with accents.
				// We use the base Latin dotless characters (U+0131, U+0237) rather than
				// the pre-styled mathematical italic versions (U+1D6A4, U+1D6A5) so that
				// font style (roman, bold, etc.) is properly applied during rendering.
				if baseChar == "i" {
					list.add(MTMathAtom(type: .ordinary, value: String(dotlessI)))
				} else if baseChar == "j" {
					list.add(MTMathAtom(type: .ordinary, value: String(dotlessJ)))
				} else {
					list.add(atom(forCharacter: baseChar))
				}
				accent.innerList = list
				return accent
			}
		}
		return nil
	}
    
    // MARK: -
    /** Gets the atom with the right type for the given character. If an atom
     cannot be determined for a given character this returns nil.
     This function follows latex conventions for assigning types to the atoms.
     The following characters are not supported and will return nil:
     - Any non-ascii character.
     - Any control character or spaces (< 0x21)
     - Latex control chars: $ % # & ~ '
     - Chars with special meaning in latex: ^ _ { } \
     All other characters, including those with accents, will have a non-nil atom returned.
     */
    public static func atom(forCharacter ch: Character) -> MTMathAtom? {
        let chStr = String(ch)
        switch chStr {
            case "\u{0410}"..."\u{044F}":
				// Cyrillic alphabet
                return MTMathAtom(type: .ordinary, value: chStr)
			case _ where supportedAccentedCharacters.keys.contains(ch):
				// support for áéíóúýàèìòùâêîôûäëïöüÿãñõçøåæœß'ÁÉÍÓÚÝÀÈÌÒÙÂÊÎÔÛÄËÏÖÜÃÑÕÇØÅÆŒ
				return atom(fromAccentedCharacter: ch)
            case _ where ch.utf32Char < 0x0021 || ch.utf32Char > 0x007E:
                return nil
            case "~":
                // LaTeX 의 묶음 공백(non-breaking space). 예전에는 nil 을 돌려줘 조용히
                // 사라졌다 — "a~b" 가 "ab" 와 픽셀 단위로 같았다.
                return MTMathSpace(space: 6)
            case "$", "%", "#", "&", "\'", "^", "_", "{", "}", "\\":
                return nil
            case "(", "[":
                return MTMathAtom(type: .open, value: chStr)
            case ")", "]", "!", "?":
                return MTMathAtom(type: .close, value: chStr)
            case ",", ";":
                return MTMathAtom(type: .punctuation, value: chStr)
            case "=", ">", "<":
                return MTMathAtom(type: .relation, value: chStr)
            case ":":
                // Math colon is ratio. Regular colon is \colon
                return MTMathAtom(type: .relation, value: "\u{2236}")
            case "-":
                return MTMathAtom(type: .binaryOperator, value: "\u{2212}")
            case "+", "*":
                return MTMathAtom(type: .binaryOperator, value: chStr)
            case ".", "0"..."9":
                return MTMathAtom(type: .number, value: chStr)
            case "a"..."z", "A"..."Z":
                return MTMathAtom(type: .variable, value: chStr)
            case "\"", "/", "@", "`", "|":
                return MTMathAtom(type: .ordinary, value: chStr)
            default:
                assertionFailure("Unknown ASCII character '\(ch)'. Should have been handled earlier.")
                return nil
        }
    }
    
    /** Returns a `MTMathList` with one atom per character in the given string. This function
     does not do any LaTeX conversion or interpretation. It simply uses `atom(forCharacter:)` to
     convert the characters to atoms. Any character that cannot be converted is ignored. */
    public static func atomList(for string: String) -> MTMathList {
        let list = MTMathList()
        for character in string {
            if let newAtom = atom(forCharacter: character) {
                list.add(newAtom)
            }
        }
        return list
    }
    
    /** Returns an atom with the right type for a given latex symbol (e.g. theta)
     If the latex symbol is unknown this will return nil. This supports LaTeX aliases as well.
     */
    public static func atom(forLatexSymbol name: String) -> MTMathAtom? {
        var name = name
        if let canonicalName = aliases[name] {
            name = canonicalName
        }
        if let atom = supportedLatexSymbols[name] {
            return atom.copy()
        }
        return nil
    }
    
    /** Finds the name of the LaTeX symbol name for the given atom. This function is a reverse
     of the above function. If no latex symbol name corresponds to the atom, then this returns `nil`
     If nucleus of the atom is empty, then this will return `nil`.
     Note: This is not an exact reverse of the above in the case of aliases. If an LaTeX alias
     points to a given symbol, then this function will return the original symbol name and not the
     alias.
     Note: This function does not convert MathSpaces to latex command names either.
     */
    public static func latexSymbolName(for atom: MTMathAtom) -> String? {
        guard !atom.nucleus.isEmpty else { return nil }
        return Self.textToLatexSymbolName[atom.nucleus]
    }
    
    /** Define a latex symbol for rendering. This function allows defining custom symbols that are
     not already present in the default set, or override existing symbols with new meaning.
     e.g. to define a symbol for "lcm" one can call:
     `MTMathAtomFactory.add(latexSymbol:"lcm", value:MTMathAtomFactory.operatorWithName("lcm", limits: false))` */
    public static func add(latexSymbol name: String, value: MTMathAtom) {
        let _ = Self.textToLatexSymbolName
        // above force textToLatexSymbolName to initialise first, _textToLatexSymbolName also initialized.
        // protect lazily loading table in a multi-thread concurrent environment
        textToLatexLock.lock()
        defer { textToLatexLock.unlock() }
        supportedLatexSymbols[name] = value
        Self._textToLatexSymbolName?[value.nucleus] = name
    }
    
    /** Returns a large opertor for the given name. If limits is true, limits are set up on
     the operator and displayed differently. */
    public static func operatorWithName(_ name: String, limits: Bool) -> MTLargeOperator {
        MTLargeOperator(value: name, limits: limits)
    }
    
    /** Returns an accent with the given name. The name of the accent is the LaTeX name
     such as `grave`, `hat` etc. If the name is not a recognized accent name, this
     returns nil. The `innerList` of the returned `MTAccent` is nil.
     */
    public static func accent(withName name: String) -> MTAccent? {
        if let accentValue = accents[name] {
            let accent = MTAccent(value: accentValue)
            // Mark stretchy arrow accents (\overleftarrow, \overrightarrow, \overleftrightarrow)
            // These should stretch to match content width
            // \vec is NOT stretchy - it should use a small fixed-size arrow
            let stretchyAccents: Set<String> = ["overleftarrow", "overrightarrow", "overleftrightarrow"]
            accent.isStretchy = stretchyAccents.contains(name)

            // Mark wide accents (\widehat, \widetilde, \widecheck)
            // These should stretch horizontally to cover content width
            // \hat, \tilde, \check are NOT wide - they use fixed-size accents
            let wideAccents: Set<String> = ["widehat", "widetilde", "widecheck"]
            accent.isWide = wideAccents.contains(name)

            return accent
        }
        return nil
    }
    
    /** Returns the accent name for the given accent. This is the reverse of the above
     function. */
    public static func accentName(_ accent: MTAccent) -> String? {
        accentValueToName[accent.nucleus]
    }
    
    /** Creates a new boundary atom for the given delimiter name. If the delimiter name
     is not recognized it returns nil. A delimiter name can be a single character such
     as '(' or a latex command such as 'uparrow'.
     @note In order to distinguish between the delimiter '|' and the delimiter '\|' the delimiter '\|'
     the has been renamed to '||'.
     */
    public static func boundary(forDelimiter name: String) -> MTMathAtom? {
        if let delimValue = Self.delimiters[name] {
            return MTMathAtom(type: .boundary, value: delimValue)
        }
        return nil
    }
    
    /** Returns the delimiter name for a boundary atom. This is a reverse of the above function.
     If the atom is not a boundary atom or if the delimiter value is unknown this returns `nil`.
     @note This is not an exact reverse of the above function. Some delimiters have two names (e.g.
     `<` and `langle`) and this function always returns the shorter name.
     */
    public static func getDelimiterName(of boundary: MTMathAtom) -> String? {
        guard boundary.type == .boundary else { return nil }
        return Self.delimValueToName[boundary.nucleus]
    }
    
    /** Returns a fraction with the given numerator and denominator. */
    public static func fraction(withNumerator num: MTMathList, denominator denom: MTMathList) -> MTFraction {
        let frac = MTFraction()
        frac.numerator = num
        frac.denominator = denom
        return frac
    }
    
    public static func mathListForCharacters(_ chars:String) -> MTMathList? {
        let list = MTMathList()
        for ch in chars {
            if let atom = self.atom(forCharacter: ch) {
                list.add(atom)
            }
        }
        return list
    }
    
    /** Simplification of above function when numerator and denominator are simple strings.
     This function converts the strings to a `MTFraction`. */
    public static func fraction(withNumeratorString numStr: String, denominatorString denomStr: String) -> MTFraction {
        let num = Self.atomList(for: numStr)
        let denom = Self.atomList(for: denomStr)
        return Self.fraction(withNumerator: num, denominator: denom)
    }
    

    static let matrixEnvs = [
        "matrix": [],
        "pmatrix": ["(", ")"],
        "bmatrix": ["[", "]"],
        "Bmatrix": ["{", "}"],
        "vmatrix": ["vert", "vert"],
        "Vmatrix": ["Vert", "Vert"],
        "smallmatrix": [],
        // Starred versions with optional alignment
        "matrix*": [],
        "pmatrix*": ["(", ")"],
        "bmatrix*": ["[", "]"],
        "Bmatrix*": ["{", "}"],
        "vmatrix*": ["vert", "vert"],
        "Vmatrix*": ["Vert", "Vert"]
    ]
    
    /** Builds a table for a given environment with the given rows. Returns a `MTMathAtom` containing the
     table and any other atoms necessary for the given environment. Returns nil and sets error
     if the table could not be built.
     @param env The environment to use to build the table. If the env is nil, then the default table is built.
     @note The reason this function returns a `MTMathAtom` and not a `MTMathTable` is because some
     matrix environments are have builtin delimiters added to the table and hence are returned as inner atoms.

     Column constraints by environment (matching KaTeX behavior):
     - `aligned`, `eqalign`: Any number of columns (1, 2, 3, 4+) with r-l-r-l alignment pattern
     - `split`: Maximum 2 columns with r-l alignment
     - `gather`, `displaylines`: Exactly 1 column, centered
     - `cases`: 1 or 2 columns, left-aligned
     - `eqnarray`: Exactly 3 columns with r-c-l alignment
     */
    public static func table(withEnvironment env: String?, alignment: MTColumnAlignment? = nil, rows: [[MTMathList]], error:inout NSError?) -> MTMathAtom? {
        let table = MTMathTable(environment: env)

        for i in 0..<rows.count {
            let row = rows[i]
            for j in 0..<row.count {
                table.set(cell: row[j], forRow: i, column: j)
            }
        }
        
        if env == nil {
            table.interColumnSpacing = 0
            table.interRowAdditionalSpacing = 1
            for i in 0..<table.numColumns {
                table.set(alignment: .left, forColumn: i)
            }
            return table
        } else if let env = env {
            if let delims = matrixEnvs[env] {
                table.environment = "matrix"

                // smallmatrix uses script style and tighter spacing for inline use
                let isSmallMatrix = (env == "smallmatrix")

                table.interRowAdditionalSpacing = 0
                table.interColumnSpacing = isSmallMatrix ? 6 : 18

                let style = MTMathStyle(style: isSmallMatrix ? .script : .text)

                for i in 0..<table.cells.count {
                    for j in 0..<table.cells[i].count {
                        table.cells[i][j].insert(style, at: 0)
                    }
                }

                // Apply alignment for starred matrix environments
                if let align = alignment {
                    for col in 0..<table.numColumns {
                        table.set(alignment: align, forColumn: col)
                    }
                }

                if delims.count == 2 {
                    let inner = MTInner()
                    inner.leftBoundary = Self.boundary(forDelimiter: delims[0])
                    inner.rightBoundary = Self.boundary(forDelimiter: delims[1])
                    inner.innerList = MTMathList(atoms: [table])
                    return inner
                } else {
                    return table
                }
            } else if env == "eqalign" || env == "split" || env == "aligned" {
                // split is limited to max 2 columns per LaTeX/KaTeX spec
                // aligned/eqalign can have any number of columns (1, 2, 3, 4+)
                if env == "split" && table.numColumns > 2 {
                    let message = "split environment can have at most 2 columns"
                    if error == nil {
                        error = NSError(domain: MTParseError, code: MTParseErrors.invalidNumColumns.rawValue, userInfo: [NSLocalizedDescriptionKey:message])
                    }
                    return nil
                }

                let spacer = MTMathAtom(type: .ordinary, value: "")

                // Add spacer at beginning of odd-indexed columns (1, 3, 5, ...)
                // This matches KaTeX behavior for binary operator spacing
                for i in 0..<table.cells.count {
                    var colIndex = 1
                    while colIndex < table.cells[i].count {
                        table.cells[i][colIndex].insert(spacer, at: 0)
                        colIndex += 2
                    }
                }

                table.interRowAdditionalSpacing = 1
                table.interColumnSpacing = 0

                // Apply alternating r-l-r-l alignment pattern
                for col in 0..<table.numColumns {
                    table.set(alignment: col % 2 == 0 ? .right : .left, forColumn: col)
                }

                return table
            } else if env == "displaylines" || env == "gather" {
                if table.numColumns != 1 {
                    let message = "\(env) environment can only have 1 column"
                    if error == nil {
                        error = NSError(domain: MTParseError, code: MTParseErrors.invalidNumColumns.rawValue, userInfo: [NSLocalizedDescriptionKey:message])
                    }
                    return nil
                }
                
                table.interRowAdditionalSpacing = 1
                table.interColumnSpacing = 0
                
                table.set(alignment: .center, forColumn: 0)
                
                return table
            } else if env == "eqnarray" {
                if table.numColumns != 3 {
                    let message = "\(env) environment can only have 3 columns"
                    if error == nil {
                        error = NSError(domain: MTParseError, code: MTParseErrors.invalidNumColumns.rawValue, userInfo: [NSLocalizedDescriptionKey:message])
                    }
                    return nil
                }
                
                table.interRowAdditionalSpacing = 1
                table.interColumnSpacing = 18
                
                table.set(alignment: .right, forColumn: 0)
                table.set(alignment: .center, forColumn: 1)
                table.set(alignment: .left, forColumn: 2)
                
                return table
            } else if env == "cases" {
                if table.numColumns != 1 && table.numColumns != 2 {
                    let message = "cases environment can have 1 or 2 columns"
                    if error == nil {
                        error = NSError(domain: MTParseError, code: MTParseErrors.invalidNumColumns.rawValue, userInfo: [NSLocalizedDescriptionKey:message])
                    }
                    return nil
                }

                table.interRowAdditionalSpacing = 0
                table.interColumnSpacing = 18

                table.set(alignment: .left, forColumn: 0)
                if table.numColumns == 2 {
                    table.set(alignment: .left, forColumn: 1)
                }
                
                let style = MTMathStyle(style: .text)
                for i in 0..<table.cells.count {
                    for j in 0..<table.cells[i].count {
                        table.cells[i][j].insert(style, at: 0)
                    }
                }
                
                let inner = MTInner()
                inner.leftBoundary = Self.boundary(forDelimiter: "{")
                inner.rightBoundary = Self.boundary(forDelimiter: ".")
                let space = Self.atom(forLatexSymbol: ",")!
                
                inner.innerList = MTMathList(atoms: [space, table])
                
                return inner
            } else {
                let message = "Unknown environment \(env)"
                error = NSError(domain: MTParseError, code: MTParseErrors.invalidEnv.rawValue, userInfo: [NSLocalizedDescriptionKey:message])
                return nil
            }
        }
        return nil
    }
}
