#if os(macOS)
import XCTest
import AppKit
@testable import SwiftMath
import SwiftMathCJKFonts

/// 중세국어(옛한글) 조판 시각 검증.
///
/// 조합형 자모·방점·한자 혼용이 한 서체로 나오는지는 단정으로 확인하기 어렵다.
/// 실행: swift test --filter MiddleKoreanRenderTests → /tmp/swiftmath-hunmin.png
final class MiddleKoreanRenderTests: XCTestCase {
    func testRender() throws {
        let font = try XCTUnwrap(MTFontManager.fontManager.latinModernFont(withSize: 26))
            .copy(withCJKSerif: .korean)
        let samples: [(String, String)] = [
            ("훈민정음 언해 서문",
             "나\u{302E}랏\u{302E}말\u{302F}\u{110A}\u{119E}미\u{302E} 中듀\u{11F0}國귁\u{302E}에\u{302E}"),
            ("한자 혼용", "訓民正音 諺解"),
            ("두시언해", "杜詩諺解 卷之一"),
            ("옛자모 모음", "\u{110A}\u{119E} \u{1140}\u{1161} \u{1159}\u{1161} \u{112B}\u{1169} \u{1103}\u{1172}\u{11F0}"),
            ("현대 대조", "나랏말싸미 중국에"),
        ]
        var rows: [(NSImage, String)] = []
        for (label, text) in samples {
            var e: NSError?
            guard let l = MTMathListBuilder.build(fromString: "\\text{\(text)}", error: &e), e == nil,
                  let d = MTTypesetter.createLineForMathList(l, font: font, style: .display) else {
                XCTFail("조판 실패: \(label)"); continue }
            let pad: CGFloat = 8
            let img = NSImage(size: NSSize(width: d.width+pad*2, height: d.ascent+d.descent+pad*2))
            img.lockFocus(); NSColor.white.setFill(); NSRect(origin:.zero,size:img.size).fill()
            if let ctx = NSGraphicsContext.current?.cgContext {
                ctx.saveGState(); ctx.translateBy(x: pad, y: pad+d.descent)
                ctx.setFillColor(NSColor.black.cgColor); d.draw(ctx); ctx.restoreGState() }
            img.unlockFocus(); rows.append((img, label))
        }
        let m: CGFloat = 14, g: CGFloat = 9, lh: CGFloat = 14
        let w = (rows.map{$0.0.size.width}.max() ?? 300)+m*2
        let h = rows.reduce(m*2){ $0+$1.0.size.height+lh+g }
        let sheet = NSImage(size: NSSize(width: max(w,480), height: h))
        sheet.lockFocus(); NSColor.white.setFill(); NSRect(origin:.zero,size:sheet.size).fill()
        var y = h-m
        for (img,label) in rows {
            y -= img.size.height+lh
            (label as NSString).draw(at: NSPoint(x:m,y:y+img.size.height),
                withAttributes:[.font:NSFont.systemFont(ofSize:10),.foregroundColor:NSColor.systemBlue])
            img.draw(at: NSPoint(x:m,y:y), from:.zero, operation:.sourceOver, fraction:1); y -= g
        }
        sheet.unlockFocus()
        if let t = sheet.tiffRepresentation, let r = NSBitmapImageRep(data:t),
           let p = r.representation(using:.png,properties:[:]) {
            try p.write(to: URL(fileURLWithPath: "/tmp/swiftmath-hunmin.png"))
            print("HUNMIN → /tmp/swiftmath-hunmin.png") }
    }
}
#endif
