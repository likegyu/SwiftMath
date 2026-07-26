
import Foundation
import CoreText

//
//  Created by Mike Griebling on 2022-12-31.
//  Translated from an Objective-C implementation by Kostub Deshmukh.
//
//  This software may be modified and distributed under the terms of the
//  MIT license. See the LICENSE file for details.
//

public class MTFont {

    var defaultCGFont: CGFont!
    var ctFont: CTFont!
    var mathTable: MTFontMathTable?
    var rawMathTable: NSDictionary?

    /// Fallback font for characters not supported by the main math font.
    /// Defaults to the system font at the same size. This is particularly useful
    /// for rendering text in \text{} commands with characters outside the math font's coverage
    /// (e.g., Chinese, Japanese, Korean, emoji, etc.)
    public var fallbackFont: CTFont?

    /// 폴백 폰트 전체 목록(우선순위 순). `copy(withFallbackFonts:)` 가 채운다.
    /// `fallbackFont` 는 이 목록의 첫 항목으로, 글리프 단위 경로가 쓰는 단일 훅이다.
    public internal(set) var fallbackFonts: [CTFont] = []

    init() {}
    
    /// `MTFont(fontWithName:)` does not load the complete math font, it only has about half the glyphs of the full math font.
    /// In particular it does not have the math italic characters which breaks our variable rendering.
    /// So we first load a CGFont from the file and then convert it to a CTFont.
    convenience init(fontWithName name: String, size:CGFloat) {
        self.init()
        //print("Loading font \(name)")
        let bundle = MTFont.fontBundle
        let fontPath = bundle.path(forResource: name, ofType: "otf")
        let fontDataProvider = CGDataProvider(filename: fontPath!)
        self.defaultCGFont = CGFont(fontDataProvider!)!
        //print("Num glyphs: \(self.defaultCGFont.numberOfGlyphs)")
        
        self.ctFont = CTFontCreateWithGraphicsFont(self.defaultCGFont, size, nil, nil);
        
        //print("Loading associated .plist")
        let mathTablePlist = bundle.url(forResource:name, withExtension:"plist")
        self.rawMathTable = NSDictionary(contentsOf: mathTablePlist!)
        self.mathTable = MTFontMathTable(withFont:self, mathTable:rawMathTable!)
    }
    
    static var fontBundle:Bundle {
        // Uses bundle for class so that this can be access by the unit tests.
        Bundle(url: Bundle.module.url(forResource: "mathFonts", withExtension: "bundle")!)!
    }
    
    /** Returns a copy of this font but with a different size. */
    public func copy(withSize size: CGFloat) -> MTFont {
        let newFont = MTFont()
        newFont.defaultCGFont = self.defaultCGFont
        // 크기만 바꾸고 **나머지 속성은 물려받는다.** 예전에는 defaultCGFont 로부터 CTFont 를
        // 새로 만들었는데, 그러면 이 폰트에 붙여 둔 디스크립터 속성이 전부 사라졌다 — 특히
        // cascade list(CJK 폴백 폰트 지정)가 유실됐다.
        //
        // 이 경로는 첨자·분수·루트처럼 **크기가 바뀌는 모든 조판**에서 불린다. 그래서 증상이
        // 기묘했다: `\text{운동}` 은 지정한 폰트로 나오는데 `E_{운동}` 의 첨자만 시스템 기본
        // 폴백으로 되돌아갔다(실측: cascade 항목 수 1 → 0).
        newFont.ctFont = CTFontCreateCopyWithAttributes(self.ctFont, size, nil, nil)
        newFont.rawMathTable = self.rawMathTable
        newFont.mathTable = MTFontMathTable(withFont: newFont, mathTable: newFont.rawMathTable!)
        return newFont
    }
    
    /// 폴백 폰트를 지정한 사본을 만든다.
    ///
    /// - Parameter fallbacks: 우선순위 순서. 앞쪽 폰트부터 글리프를 찾는다.
    /// - Returns: 원본은 그대로 두고, 폴백만 얹은 새 `MTFont`.
    ///
    /// 시스템 기본 폴백 체인은 **뒤에 그대로 붙인다.** `kCTFontCascadeListAttribute` 를
    /// 지정하면 기본 체인이 통째로 대체되기 때문에, 그냥 두면 지정한 폰트가 못 그리는
    /// 문자(예: 한글 전용 서브셋에 없는 한자)가 두부(.notdef)로 나온다. 기본 체인을
    /// 뒤에 이어 붙여 두면 그런 문자는 최소한 시스템 폰트로는 나온다.
    ///
    /// 확장이 아니라 클래스 본문에 있는 이유: `MTFontV2` 가 재정의해야 한다. 확장 메서드는
    /// 정적 디스패치라 재정의할 수 없다.
    public func copy(withFallbackFonts fallbacks: [CTFont]) -> MTFont {
        let size = self.fontSize
        let newFont = MTFont()
        newFont.defaultCGFont = self.defaultCGFont
        newFont.ctFont = MTFont.cascaded(self.ctFont, size: size, fallbacks: fallbacks)
        // 글리프 단위 경로(근호·큰 연산자·구분자·악센트)는 CTLine 을 타지 않아 캐스케이드가
        // 닿지 않는다. 그쪽이 쓰는 단일 폴백 훅도 같이 채워 둔다.
        newFont.fallbackFont = fallbacks.first
        newFont.fallbackFonts = fallbacks
        newFont.rawMathTable = self.rawMathTable
        // 수학 테이블은 ctFont 를 **확정한 뒤에** 만든다 — 생성 시점에 unitsPerEm 과
        // 폰트 크기를 즉시 읽어 가기 때문이다.
        newFont.mathTable = MTFontMathTable(withFont: newFont, mathTable: newFont.rawMathTable!)
        return newFont
    }

    /// 주어진 폰트에 폴백 캐스케이드를 얹은 CTFont. 폴백이 비면 크기만 맞춘 사본.
    static func cascaded(_ base: CTFont, size: CGFloat, fallbacks: [CTFont]) -> CTFont {
        guard !fallbacks.isEmpty else {
            return CTFontCreateCopyWithAttributes(base, size, nil, nil)
        }
        var cascade = fallbacks.map { CTFontCopyFontDescriptor($0) }
        if let defaults = CTFontCopyDefaultCascadeListForLanguages(base, nil) as? [CTFontDescriptor] {
            cascade.append(contentsOf: defaults)
        }
        // 디스크립터를 **속성으로만** 넘긴다. `CTFontCreateWithFontDescriptor` 로 새로 만들면
        // CoreText 가 기반 폰트를 이름으로 다시 찾는데, 수학 폰트는 시스템에 등록돼 있지 않아
        // 엉뚱한 폰트(Helvetica)로 해석될 수 있다. 이 함수는 원본 데이터를 그대로 들고 간다.
        let attrs = CTFontDescriptorCreateWithAttributes(
            [kCTFontCascadeListAttribute: cascade] as CFDictionary)
        return CTFontCreateCopyWithAttributes(base, size, nil, attrs)
    }

    func get(nameForGlyph glyph:CGGlyph) -> String {
        let name = defaultCGFont.name(for: glyph) as? String
        return name ?? ""
    }
    
    func get(glyphWithName name:String) -> CGGlyph {
        defaultCGFont.getGlyphWithGlyphName(name: name as CFString)
    }
    
    /** The size of this font in points. */
    public var fontSize:CGFloat { CTFontGetSize(self.ctFont) }
    
    deinit {
        self.ctFont = nil
        self.defaultCGFont = nil
    }
    
}
