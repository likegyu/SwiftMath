import Foundation
import CoreText

//
//  수학 폰트가 못 그리는 문자(주로 CJK)를 어떤 폰트로 대신 그릴지 지정하는 통로.
//
//  왜 필요한가: 수학 폰트(Latin Modern, XITS 등)에는 한글·한자·가나 글리프가 없다.
//  지정하지 않으면 CoreText 의 시스템 기본 폴백이 고르는데, Apple 플랫폼에서 한글은
//  AppleSDGothicNeo(고딕)뿐이라 한 수식 안에서 라틴은 세리프, 한글은 산세리프가 되는
//  내부 불일치가 생긴다. 여기서 명조 계열을 얹으면 수식 한 덩이의 서체가 일관된다.
//

extension MTFont {

    /// 시스템에 등록된 폰트를 이름으로 지정한다. 없는 이름은 조용히 건너뛴다.
    ///
    /// 등록되지 않은 이름을 그대로 캐스케이드에 넣으면 CoreText 가 임의의 폰트로
    /// 해석해 버려서, 지정한 적 없는 서체가 수식에 섞인다. 그래서 실재하는 이름만 남긴다.
    public func copy(withFallbackFontNames names: [String]) -> MTFont {
        let size = self.fontSize
        let fonts = names.compactMap { MTFont.systemFont(named: $0, size: size) }
        return self.copy(withFallbackFonts: fonts)
    }

    /// 이름으로 시스템 폰트를 만든다. 그 이름의 폰트가 실제로 없으면 nil.
    ///
    /// CoreText 는 없는 이름을 줘도 대체 폰트를 만들어 돌려주기 때문에, 돌아온 폰트의
    /// PostScript 이름·패밀리 이름이 요청과 맞는지 확인해야 "없음"을 알 수 있다.
    public static func systemFont(named name: String, size: CGFloat) -> CTFont? {
        let font = CTFontCreateWithName(name as CFString, size, nil)
        let post = CTFontCopyPostScriptName(font) as String
        let family = CTFontCopyFamilyName(font) as String
        let requested = name.replacingOccurrences(of: " ", with: "")
        guard post.replacingOccurrences(of: " ", with: "").caseInsensitiveCompare(requested) == .orderedSame
                || family.replacingOccurrences(of: " ", with: "").caseInsensitiveCompare(requested) == .orderedSame
        else { return nil }
        return font
    }
}
