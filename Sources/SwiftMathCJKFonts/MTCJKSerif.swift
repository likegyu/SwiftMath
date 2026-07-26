import CoreText
import Foundation
import SwiftMath

/// 수식 안 CJK 를 그릴 **명조(明朝/宋体) 계열** 폰트.
///
/// 왜 별도 모듈인가: Apple 플랫폼에는 한글 세리프가 아예 없고(AppleSDGothicNeo 7종이
/// 전부), 중국어도 세리프가 없다. 그래서 폰트를 직접 실어야 하는데, 그 5.4MB 를 CJK 를
/// 쓰지 않는 SwiftMath 사용자에게까지 지울 이유는 없다. 이 모듈을 링크한 쪽만 지불한다.
///
/// ```swift
/// let font = MTFontManager.fontManager.latinModernFont(withSize: 20)!
///     .copy(withCJKSerif: .korean)
/// ```
public enum MTCJKSerif: String, CaseIterable, Sendable {
    /// 한국어 — SwiftMath Serif KR(Noto Serif KR 서브셋). 한글 음절 11,172자 전부.
    case korean
    /// 중국어 간체 — SwiftMath Serif SC(Noto Serif SC 서브셋). GB2312 1급 3,755자.
    case simplifiedChinese
    /// 일본어 — 시스템 히라기노 명조(Hiragino Mincho ProN). 번들하지 않는다.
    ///
    /// iOS·macOS 에 기본 탑재돼 있고 무료로 쓸 수 있어서, 실어 봐야 중복이다.
    case japanese

    /// 이 선택에 해당하는 폰트. 만들 수 없으면 nil(호출부는 시스템 폴백으로 두면 된다).
    public func ctFont(size: CGFloat) -> CTFont? {
        switch self {
        case .korean:
            return BundledCJKFont.ctFont(resource: "SwiftMathSerifKR-Regular",
                                         postScriptName: "SwiftMathSerifKR-Regular", size: size)
        case .simplifiedChinese:
            return BundledCJKFont.ctFont(resource: "SwiftMathSerifSC-Regular",
                                         postScriptName: "SwiftMathSerifSC-Regular", size: size)
        case .japanese:
            return ["HiraMinProN-W3", "HiraMinPro-W3", "HiraginoSerif-W3"]
                .lazy.compactMap { MTFont.systemFont(named: $0, size: size) }.first
        }
    }
}

extension MTFont {
    /// 지정한 CJK 명조를 폴백으로 얹은 사본.
    ///
    /// 여러 언어를 함께 넘기면 앞쪽이 우선한다. 한 수식에 한글과 한자가 섞이는 경우가
    /// 아니면 하나만 넘기면 된다 — 지정하지 않은 문자는 시스템 폴백이 받는다.
    public func copy(withCJKSerif serifs: MTCJKSerif...) -> MTFont {
        self.copy(withCJKSerifs: serifs)
    }

    /// 배열을 받는 형태. 사용자가 고른 언어가 런타임 값일 때 쓴다.
    public func copy(withCJKSerifs serifs: [MTCJKSerif]) -> MTFont {
        let size = self.fontSize
        return self.copy(withFallbackFonts: serifs.compactMap { $0.ctFont(size: size) })
    }
}

/// 번들 폰트를 프로세스에 등록하고 이름으로 찾을 수 있게 만든다.
///
/// 등록 없이 `CGFont` 에서 만든 `CTFont` 를 캐스케이드 목록에 넣으면, CoreText 가 그
/// 디스크립터를 **이름으로 다시 해석**하다가 시스템에 없는 폰트라 엉뚱한 서체로 떨어진다.
/// 프로세스 범위 등록을 한 번 해 두면 이름 해석이 정상 동작한다.
private enum BundledCJKFont {
    private static let lock = NSLock()
    private static var registered = Set<String>()

    static func ctFont(resource: String, postScriptName: String, size: CGFloat) -> CTFont? {
        lock.lock()
        let needsRegistration = !registered.contains(resource)
        if needsRegistration, register(resource: resource) {
            registered.insert(resource)
        }
        lock.unlock()
        return MTFont.systemFont(named: postScriptName, size: size)
    }

    private static func register(resource: String) -> Bool {
        guard let bundleURL = Bundle.module.url(forResource: "cjkFonts", withExtension: "bundle"),
              let bundle = Bundle(url: bundleURL),
              let url = bundle.url(forResource: resource, withExtension: "otf"),
              let provider = CGDataProvider(url: url as CFURL),
              let cgFont = CGFont(provider)
        else { return false }

        var error: Unmanaged<CFError>?
        if CTFontManagerRegisterGraphicsFont(cgFont, &error) { return true }
        // 이미 등록된 경우(105)는 성공으로 친다 — 같은 폰트가 두 경로로 들어올 수 있다.
        let code = (error?.takeRetainedValue()).map { CFErrorGetCode($0) } ?? -1
        return code == 105
    }
}
