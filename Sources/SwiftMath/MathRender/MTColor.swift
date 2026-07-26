
//
//  Created by Mike Griebling on 2022-12-31.
//  Translated from an Objective-C implementation by Markus Sähn.
//
//  This software may be modified and distributed under the terms of the
//  MIT license. See the LICENSE file for details.
//

import Foundation

extension MTColor {
    
    public convenience init?(fromHexString hexString:String) {
        if hexString.isEmpty { return nil }
        if !hexString.hasPrefix("#") { return nil }
        
        var rgbValue = UInt64(0)
        let scanner = Scanner(string: hexString)
        scanner.charactersToBeSkipped = CharacterSet(charactersIn: "#")
        scanner.scanHexInt64(&rgbValue)
        self.init(red: CGFloat((rgbValue & 0xFF0000) >> 16)/255.0,
                  green: CGFloat((rgbValue & 0xFF00) >> 8)/255.0,
                  blue: CGFloat((rgbValue & 0xFF))/255.0,
                  alpha: 1.0)
    }

    /// LaTeX 색 지정을 해석한다 — `\textcolor{red}{…}` 의 `red` 나 `#FF0000`.
    ///
    /// 이름은 xcolor 의 기본 팔레트를 따른다. 모르는 이름은 nil 이고, 그때 호출부는
    /// 색을 입히지 않되 **내용은 그대로 그린다** — 색 하나 못 알아들었다고 수식을
    /// 통째로 버리는 건 이 버그의 원래 증상이었다.
    public static func fromLatexColorName(_ name: String) -> MTColor? {
        let key = name.trimmingCharacters(in: .whitespaces)
        if key.hasPrefix("#") { return MTColor(fromHexString: key) }

        func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> MTColor {
            MTColor(red: r / 255, green: g / 255, blue: b / 255, alpha: 1)
        }
        // xcolor 기본 색 이름. dvipsnames 전체는 68개지만, 실제로 쓰이는 건 이 정도다.
        switch key.lowercased() {
        case "red":       return rgb(255, 0, 0)
        case "green":     return rgb(0, 128, 0)
        case "blue":      return rgb(0, 0, 255)
        case "cyan":      return rgb(0, 255, 255)
        case "magenta":   return rgb(255, 0, 255)
        case "yellow":    return rgb(255, 255, 0)
        case "black":     return rgb(0, 0, 0)
        case "white":     return rgb(255, 255, 255)
        case "gray", "grey":           return rgb(128, 128, 128)
        case "darkgray", "darkgrey":   return rgb(64, 64, 64)
        case "lightgray", "lightgrey": return rgb(192, 192, 192)
        case "brown":     return rgb(150, 75, 0)
        case "lime":      return rgb(191, 255, 0)
        case "olive":     return rgb(128, 128, 0)
        case "orange":    return rgb(255, 128, 0)
        case "pink":      return rgb(255, 191, 191)
        case "purple":    return rgb(128, 0, 128)
        case "teal":      return rgb(0, 128, 128)
        case "violet":    return rgb(128, 0, 255)
        default:          return nil
        }
    }
}
