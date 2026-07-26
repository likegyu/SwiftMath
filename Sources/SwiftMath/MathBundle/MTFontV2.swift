//
//  MTFontV2.swift
//
//
//  Created by Peter Tang on 15/9/2023.
//

import Foundation
import CoreGraphics
import CoreText

extension MathFont {
    public func mtfont(size: CGFloat) -> MTFontV2 {
        MTFontV2(font: self, size: size)
    }
}
public final class MTFontV2: MTFont {
    let font: MathFont
    let size: CGFloat
    private let _cgFont: CGFont
    private let _ctFont: CTFont
    private let unitsPerEm: UInt
    private var _mathTab: MTFontMathTableV2?
    /// 이 폰트에 얹힌 폴백들. 크기를 바꿔도 따라가야 해서 인스턴스가 들고 있는다.
    private let _fallbacks: [CTFont]

    init(font: MathFont = .latinModernFont, size: CGFloat, fallbacks: [CTFont] = []) {
        self.font = font
        self.size = size
        self._fallbacks = fallbacks
        // MathFont cgfont and ctfont are fast & threadsafe, keep a local copy is cheaper than
        // handling via NSLock
        self._cgFont = font.cgFont()
        let base = font.ctFont(withSize: size)
        self._ctFont = MTFont.cascaded(base, size: size, fallbacks: fallbacks)
        // unitsPerEm 은 캐스케이드와 무관한 기반 폰트의 값을 쓴다.
        self.unitsPerEm = base.unitsPerEm
        super.init()

        super.defaultCGFont = nil
        super.ctFont = nil
        super.mathTable = nil
        super.rawMathTable = nil
        super.fallbackFont = fallbacks.first
        super.fallbackFonts = fallbacks
    }
    override var defaultCGFont: CGFont! {
        set { fatalError("\(#function): change to \(font.fontName) not allowed.") }
        get { _cgFont }
    }
    override var ctFont: CTFont! {
        set { fatalError("\(#function): change to \(font.fontName) not allowed.") }
        get { _ctFont }
    }
    private let mtfontV2LockOnMathTable = NSLock()
    override var mathTable: MTFontMathTable? {
        set { fatalError("\(#function): change to \(font.rawValue) not allowed.") }
        get {
            guard _mathTab == nil else { return _mathTab }
            //Note: lazy _mathTab initialization is now threadsafe.
            mtfontV2LockOnMathTable.lock()
            defer { mtfontV2LockOnMathTable.unlock() }
            if _mathTab == nil {
                _mathTab = MTFontMathTableV2(mathFont: font, size: size, unitsPerEm: unitsPerEm)
            }
            return _mathTab
        }
    }
    override var rawMathTable: NSDictionary? {
        set { fatalError("\(#function): change to \(font.rawValue) not allowed.") }
        get { fatalError("\(#function): access to \(font.rawValue) not allowed.") }
    }
    public override func copy(withSize size: CGFloat) -> MTFont {
        // 폴백을 물려준다. 첨자·분수처럼 크기가 줄어드는 경로에서 이걸 놓치면
        // 그 부분만 CJK 서체가 시스템 기본으로 되돌아간다.
        MTFontV2(font: font, size: size, fallbacks: _fallbacks)
    }

    public override func copy(withFallbackFonts fallbacks: [CTFont]) -> MTFont {
        // 상위 구현은 rawMathTable 을 읽는데 MTFontV2 는 그 접근에서 죽는다.
        // V2 는 수학 테이블을 MathFont 로부터 직접 만들므로 재생성이 곧 정답이다.
        MTFontV2(font: font, size: size, fallbacks: fallbacks)
    }
}
