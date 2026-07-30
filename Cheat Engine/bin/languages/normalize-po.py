#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Reconstruye los .po de cada idioma sobre una plantilla comun.

    python3 normalize-po.py [--apply]

Cada pack de la web viene de una version distinta de Cheat Engine, asi que
sus msgid no coinciden entre si ni con el binario actual: pt_BR trae 2530
entradas y ja_JP 4686. Las que sobran no se usan y las que faltan salen en
ingles aunque el idioma este "al 78%".

Esto toma los msgid de la plantilla (de_DE, la mas completa del repo),
rellena cada uno con la traduccion que ese idioma ya tuviera y deja vacio el
resto. No inventa traducciones: solo las reordena contra un indice comun.

De paso arregla dos cosas del formato:
  - las cadenas partidas en varias lineas, que gettext concatena y que un
    reemplazo linea a linea deja a medias
  - los escapes rotos que traen algunos packs ("c:\\x" con una sola barra)

Sin --apply solo informa de lo que cambiaria.
"""
import re, io, os, sys

TEMPLATE = 'de_DE/cheatengine-x86_64.po'

_ESC = {'n': '\n', 't': '\t', 'r': '\r', '"': '"', '\\': '\\'}
_LINE = re.compile(r'^\s*"((?:[^"\\]|\\.)*)"\s*$')


def unescape(s):
    return re.sub(r'\\(.)', lambda m: _ESC.get(m.group(1), '\\' + m.group(1)), s)


def escape(s):
    s = s.replace('\\', '\\\\').replace('"', '\\"')
    return s.replace('\n', '\\n').replace('\t', '\\t').replace('\r', '\\r')


def field(block, kw):
    lines = block.split('\n')
    for i, l in enumerate(lines):
        if l.startswith(kw):
            m = re.match(r'^%s\s+"((?:[^"\\]|\\.)*)"\s*$' % kw, l)
            if not m:
                return None
            parts, j = [m.group(1)], i + 1
            while j < len(lines) and _LINE.match(lines[j]):
                parts.append(_LINE.match(lines[j]).group(1))
                j += 1
            return unescape(''.join(parts))
    return None


def match_newlines(msgid, msgstr):
    """gettext exige que msgid y msgstr empiecen y terminen igual respecto a
    los saltos de linea. Algunos packs no lo cumplen y al reemparejarlos con
    otra plantilla el desajuste sale a la luz."""
    if not msgstr:
        return msgstr
    if msgid.startswith('\n'):
        if not msgstr.startswith('\n'):
            msgstr = '\n' + msgstr
    else:
        msgstr = msgstr.lstrip('\n')
    if msgid.endswith('\n'):
        if not msgstr.endswith('\n'):
            msgstr = msgstr + '\n'
    else:
        msgstr = msgstr.rstrip('\n')
    return msgstr


def set_msgstr(block, texto):
    lines, out, i = block.split('\n'), [], 0
    while i < len(lines):
        if lines[i].startswith('msgstr'):
            out.append('msgstr "%s"' % escape(texto))
            i += 1
            while i < len(lines) and _LINE.match(lines[i]):
                i += 1
            continue
        out.append(lines[i])
        i += 1
    return '\n'.join(out)


def load(path):
    txt = io.open(path, encoding='utf-8', errors='replace').read()
    txt = txt.replace('\r\n', '\n').replace('\r', '\n')
    out = {}
    for b in txt.split('\n\n'):
        k, v = field(b, 'msgid'), field(b, 'msgstr')
        if k and v:
            out[k] = v
    return out


def main():
    apply = '--apply' in sys.argv
    here = os.path.dirname(os.path.abspath(__file__)) or '.'
    os.chdir(here)

    tpl = io.open(TEMPLATE, encoding='utf-8', errors='replace').read()
    blocks = [b for b in tpl.split('\n\n') if b.strip()]
    total = sum(1 for b in blocks if field(b, 'msgid'))

    print('plantilla: %s (%d cadenas)\n' % (TEMPLATE, total))
    print('%-10s %8s %8s  %s' % ('idioma', 'antes', 'despues', ''))

    for d in sorted(os.listdir('.')):
        if not os.path.isdir(d):
            continue
        cands = [x for x in os.listdir(d)
                 if x.lower().startswith('cheatengine') and x.endswith('.po')]
        if not cands:
            print('%-10s %8s %8s  sin traduccion de interfaz' % (d, '-', '-'))
            continue

        src = os.path.join(d, cands[0])
        tr = load(src)
        antes = len(tr)

        out, hit = [], 0
        for b in blocks:
            key = field(b, 'msgid')
            if not key:          #cabecera
                out.append(b)
                continue
            v = match_newlines(key, tr.get(key, ''))
            if v:
                hit += 1
            out.append(set_msgstr(b, v))

        pct = hit * 100 // total
        marca = '' if hit >= antes else '  (%d entradas del pack no existen ya)' % (antes - hit)
        print('%-10s %8d %8d  %3d%%%s' % (d, antes, hit, pct, marca))

        if apply:
            io.open(src, 'w', encoding='utf-8', newline='\n').write('\n\n'.join(out) + '\n')

    if not apply:
        print('\n(sin --apply no se ha escrito nada)')


if __name__ == '__main__':
    main()
