"""Uzbek Latin -> Uzbek Cyrillic for the app's texts: lib/l10n/app_uz.arb -> lib/l10n/app_uz_Cyrl.arb.

Run after changing app_uz.arb (then `flutter gen-l10n`):  python tool/uz_cyrl.py
Placeholders ({name}), ICU keywords (plural / other / =1), links and names like Diamoraa or QR stay as they are.
"""
import json
import re
from pathlib import Path

L10N = Path(__file__).resolve().parent.parent / 'lib' / 'l10n'
APOS = "'‘’ʻʼ`"
VOWELS = set('aeiouAEIOUаеиоуўэюяёАЕИОУЎЭЮЯЁ')
SINGLE = {
    'a': 'а', 'b': 'б', 'c': 'ц', 'd': 'д', 'e': 'е', 'f': 'ф', 'g': 'г', 'h': 'ҳ', 'i': 'и', 'j': 'ж', 'k': 'к', 'l': 'л',
    'm': 'м', 'n': 'н', 'o': 'о', 'p': 'п', 'q': 'қ', 'r': 'р', 's': 'с', 't': 'т', 'u': 'у', 'v': 'в', 'w': 'в', 'x': 'х',
    'y': 'й', 'z': 'з',
}
DIGRAPH = {'sh': 'ш', 'ch': 'ч', 'yo': 'ё', 'yu': 'ю', 'ya': 'я', 'ye': 'е'}
KEEP = re.compile(
    r'https?://\S+|\{\w+(?:,\s*(?:plural|select|selectordinal)\s*,)?|(?:=\d+|zero|one|two|few|many|other)\s*\{|\}'
    r'|\b(?:Diamoraa|QR|GPS|PDF|PIN|SMS|ID|MB|KB|GB|CSV|Excel|Android|iPhone|iOS|Wi-?Fi|OK|Google|USB|APK)\b'
)


def cased(src: str, out: str) -> str:
    return out.upper() if src[:1].isupper() else out


def translit(text: str) -> str:
    out = []
    i = 0
    n = len(text)
    while i < n:
        c = text[i]
        low = c.lower()
        nxt = text[i + 1] if i + 1 < n else ''
        prev = text[i - 1] if i > 0 else ''
        word_start = not prev.isalpha() and prev not in APOS
        if low in 'og' and nxt in APOS:
            out.append(cased(c, 'ў' if low == 'o' else 'ғ'))
            i += 2
            continue
        pair = (c + nxt).lower()
        if pair in DIGRAPH and nxt.isalpha():
            out.append(cased(c, DIGRAPH[pair]))
            i += 2
            continue
        if c in APOS:
            # tutuq belgisi after a letter -> ъ; a quote around words stays a quote
            out.append('ъ' if prev.isalpha() and nxt.isalpha() else c)
            i += 1
            continue
        if low == 'e':
            out.append(cased(c, 'э' if word_start or prev in VOWELS else 'е'))
            i += 1
            continue
        if low in SINGLE and c.isascii():
            out.append(cased(c, SINGLE[low]))
            i += 1
            continue
        out.append(c)
        i += 1
    return ''.join(out)


def convert(value: str) -> str:
    parts = []
    last = 0
    for m in KEEP.finditer(value):
        parts.append(translit(value[last:m.start()]))
        parts.append(m.group(0))
        last = m.end()
    parts.append(translit(value[last:]))
    return ''.join(parts)


def main():
    src = json.loads((L10N / 'app_uz.arb').read_text(encoding='utf-8'))
    out = {'@@locale': 'uz_Cyrl'}
    for k, v in src.items():
        if k.startswith('@'):
            continue
        out[k] = convert(v) if isinstance(v, str) else v
    (L10N / 'app_uz_Cyrl.arb').write_text(json.dumps(out, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'{len(out) - 1} texts')


if __name__ == '__main__':
    main()
