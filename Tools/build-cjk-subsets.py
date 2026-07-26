#!/usr/bin/env python3
"""SwiftMathCJKFonts 에 들어가는 명조 서브셋을 만든다.

왜 서브셋인가: 원본 Noto Serif KR/SC 는 각각 7.7MB / 11.6MB 다. 수식 안에서 쓰이는
문자만 남기면 4.0MB / 1.5MB 로 줄어든다. 앱 다운로드 크기에 그대로 얹히는 값이라
줄일 수 있으면 줄이는 게 맞다.

왜 이름을 바꾸는가: "Noto" 는 Google 의 상표다(원본 name ID 7). 글리프를 덜어낸
파생물을 원래 이름으로 배포하면 안 된다. OFL 1.1 은 Reserved Font Name 이 지정돼
있지 않으면 개명을 허용하며, 저작권·라이선스 표기(name ID 0/13/14)는 그대로 남긴다.

사용법:
    python3 Tools/build-cjk-subsets.py <원본디렉터리> <출력디렉터리>

원본은 https://github.com/notofonts/noto-cjk/releases/tag/Serif2.003 의
13_NotoSerifKR.zip / 14_NotoSerifSC.zip 안에 있는 SubsetOTF/{KR,SC}/*-Regular.otf.
"""
import os
import subprocess
import sys

from fontTools.ttLib import TTFont

# 라틴·문장부호 — 수식 안 CJK 구간에도 괄호나 숫자가 섞여 들어온다.
COMMON = ("U+0020-007E,U+00A0-00FF,U+2000-206F,U+20A0-20BF,U+2100-214F,"
          "U+3000-303F,U+FF01-FF60,U+FFE0-FFE6")

# 한글은 조합 가능한 음절 11,172자를 **전부** 넣는다. 상용 2,350자만 넣으면 드물게
# 빠진 음절이 시스템 고딕으로 떨어져 한 단어 안에서 서체가 갈린다.
#
# 조합형 자모(U+1100–11FF)와 확장 A/B, 방점(U+302E–302F)도 남긴다 — 중세국어(옛한글)는
# 미리 만들어진 음절이 없어 이 구간으로만 표현된다. iOS 시스템 폰트에는 옛자모가
# 하나도 없어서(실측), 여기서 빼면 중세국어를 그릴 방법이 아예 사라진다.
#
# 한자도 넣는다(+3.1MB). 중세국어는 한자 혼용이 기본이라(훈민정음 언해·두시언해),
# 빼면 한 줄 안에서 한글은 명조, 한자는 시스템 고딕으로 갈린다.
KR_RANGES = (COMMON + ",U+1100-11FF,U+3130-318F,U+A960-A97F,U+AC00-D7A3,U+D7B0-D7FF"
             ",U+302E-302F,U+4E00-9FFF,U+F900-FAFF")


def gb2312_level1():
    """GB2312 1급 한자 3,755자 — 현대 중국어 텍스트의 99.7%를 덮는다.

    한자는 한글과 달리 자수가 2만을 넘어 전부 넣으면 8.4MB 다. 빠진 한자는 캐스케이드
    뒤쪽의 시스템 폰트(PingFang)가 받아 준다.
    """
    out = []
    for hi in range(0xB0, 0xD8):
        for lo in range(0xA1, 0xFF):
            try:
                out.append(bytes([hi, lo]).decode("gb2312"))
            except UnicodeDecodeError:
                pass
    return out


def rename(path, family, postscript):
    font = TTFont(path)
    name = font["name"]
    for record in list(name.names):
        if record.nameID in (1, 3, 4, 16, 17):        # family / unique / full / typographic
            name.setName(family if record.nameID != 4 else f"{family} Regular",
                         record.nameID, record.platformID, record.platEncID, record.langID)
        elif record.nameID == 6:                       # PostScript
            name.setName(postscript, 6, record.platformID, record.platEncID, record.langID)
        elif record.nameID == 7:                       # 상표 — 파생물에는 붙이지 않는다
            name.removeNames(7, record.platformID, record.platEncID, record.langID)
    if "CFF " in font:                                 # CFF 내부 이름도 같이 맞춘다
        cff = font["CFF "].cff
        cff.fontNames[0] = postscript
    font.save(path)


def build(src, unicodes, out, family, postscript):
    subprocess.run(["python3", "-m", "fontTools.subset", src,
                    f"--unicodes={unicodes}", f"--output-file={out}",
                    "--layout-features=*", "--name-IDs=*"], check=True)
    rename(out, family, postscript)
    print(f"{os.path.basename(out):32s} {os.path.getsize(out) / 1e6:5.2f}MB"
          f"  (원본 {os.path.getsize(src) / 1e6:.2f}MB)")


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        return 1
    src_dir, out_dir = sys.argv[1], sys.argv[2]
    os.makedirs(out_dir, exist_ok=True)

    sc_unicodes = COMMON + ",U+3100-312F," + ",".join(f"U+{ord(c):04X}" for c in gb2312_level1())
    build(os.path.join(src_dir, "NotoSerifKR-Regular.otf"), KR_RANGES,
          os.path.join(out_dir, "SwiftMathSerifKR-Regular.otf"),
          "SwiftMath Serif KR", "SwiftMathSerifKR-Regular")
    build(os.path.join(src_dir, "NotoSerifSC-Regular.otf"), sc_unicodes,
          os.path.join(out_dir, "SwiftMathSerifSC-Regular.otf"),
          "SwiftMath Serif SC", "SwiftMathSerifSC-Regular")
    return 0


if __name__ == "__main__":
    sys.exit(main())
