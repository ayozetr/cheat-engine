#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Genera los juegos de iconos de Cheat Engine en estilo Lucide.

    python3 build-icons.py <carpeta destino> <carpeta temporal>

Un catalogo de dibujos por nombre y, aparte, el mapa de cada TImageList
(indice -> nombre). Muchos iconos se repiten entre ventanas (copiar, pegar,
guardar, deshacer...), asi que se dibujan una sola vez.

El trazo se engorda en los tamanos pequenos: 2px sobre un lienzo de 24 queda
en 1.3px al reducir a 16, que es el tamano que usan los menus, y el dibujo se
emborrona.
"""
import os, subprocess, sys

SIZES = [12, 16, 20, 21, 22, 23, 24, 28, 32, 48]


def stroke_for(size):
    if size <= 16: return 2.6
    if size <= 20: return 2.3
    if size <= 28: return 2.0
    return 1.9


def hdr(stroke):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" '
            'viewBox="0 0 24 24" fill="none" stroke="#D8D8D8" '
            'stroke-width="%s" stroke-linecap="round" '
            'stroke-linejoin="round">' % stroke)


C = {
# --- archivo y edicion ---
"trash": '<path d="M3 6h18"/><path d="M8 6V4a1 1 0 0 1 1-1h6a1 1 0 0 1 1 1v2"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6"/><path d="M10 11v6"/><path d="M14 11v6"/>',
"folder-open": '<path d="M6 14.5 8 10h13l-2.7 6.4a2 2 0 0 1-1.8 1.1H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4l2 3h5a2 2 0 0 1 2 2v2"/>',
"folder-input": '<path d="M3 8V5a2 2 0 0 1 2-2h4l2 3h5a2 2 0 0 1 2 2v1"/><path d="M3 13v6a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-6"/><path d="M12 4v9"/><path d="m8.5 9.5 3.5 3.5 3.5-3.5"/>',
"save": '<path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z"/><path d="M17 21v-8H7v8"/><path d="M7 3v5h8"/>',
"save-as": '<path d="M13 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v4"/><path d="M7 3v5h8"/><path d="M18.5 14.5 21 17l-4 4h-2.5v-2.5z"/>',
"file-plus": '<path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8z"/><path d="M14 3v5h5"/><path d="M12 11v6"/><path d="M9 14h6"/>',
"file-text": '<path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8z"/><path d="M14 3v5h5"/><path d="M8 13h8"/><path d="M8 17h5"/>',
"copy": '<rect x="9" y="9" width="12" height="12" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/>',
"clipboard": '<rect x="8" y="2" width="8" height="4" rx="1"/><path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"/>',
"scissors": '<circle cx="6" cy="6" r="3"/><circle cx="6" cy="18" r="3"/><path d="M20 4 8.1 15.9"/><path d="m8.1 8.1 11.9 11.9"/>',
"undo": '<path d="M9 14 4 9l5-5"/><path d="M4 9h10a6 6 0 0 1 0 12h-3"/>',
"redo": '<path d="m15 14 5-5-5-5"/><path d="M20 9H10a6 6 0 0 0 0 12h3"/>',
"search": '<circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/>',
"search-replace": '<circle cx="10" cy="10" r="6"/><path d="m19 19-4.5-4.5"/><path d="M14 4h6v6"/>',
"close": '<path d="M18 6 6 18"/><path d="m6 6 12 12"/>',
"exit": '<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><path d="m16 17 5-5-5-5"/><path d="M21 12H9"/>',
"pencil": '<path d="M17 3a2.85 2.85 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5z"/><path d="m15 5 4 4"/>',
"rename": '<path d="M4 7V5a1 1 0 0 1 1-1h14a1 1 0 0 1 1 1v2"/><path d="M9 20h6"/><path d="M12 4v16"/>',
"check-syntax": '<path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8z"/><path d="M14 3v5h5"/><path d="m9 14 2 2 4-4"/>',
"move-right": '<path d="M5 12h14"/><path d="m13 6 6 6-6 6"/>',
"move-left": '<path d="M19 12H5"/><path d="m11 18-6-6 6-6"/>',
"tab-plus": '<path d="M3 19V7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><path d="M12 11v5"/><path d="M9.5 13.5h5"/>',
"new-window": '<rect x="3" y="4" width="18" height="16" rx="2"/><path d="M3 9h18"/><path d="M12 13v4"/><path d="M10 15h4"/>',
"app-window": '<rect x="3" y="4" width="18" height="16" rx="2"/><path d="M3 9h18"/><path d="M6.5 6.5h.01"/><path d="M9.5 6.5h.01"/>',
"settings": '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 1 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 1 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.6h.09A1.65 1.65 0 0 0 10 3.09V3a2 2 0 1 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9v.09a1.65 1.65 0 0 0 1.51 1H21a2 2 0 1 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/>',
"sliders": '<path d="M4 6h10"/><path d="M18 6h2"/><path d="M4 12h4"/><path d="M12 12h8"/><path d="M4 18h10"/><path d="M18 18h2"/><circle cx="16" cy="6" r="2"/><circle cx="10" cy="12" r="2"/><circle cx="16" cy="18" r="2"/>',
"palette": '<circle cx="13.5" cy="6.5" r="1.2"/><circle cx="17.5" cy="10.5" r="1.2"/><circle cx="8.5" cy="7.5" r="1.2"/><circle cx="6.5" cy="12.5" r="1.2"/><path d="M12 2a10 10 0 1 0 0 20 2.5 2.5 0 0 0 1.8-4.2 2.5 2.5 0 0 1 1.8-4.3H19a3 3 0 0 0 3-3 10 10 0 0 0-10-8.5z"/>',
"info": '<circle cx="12" cy="12" r="9"/><path d="M12 11v5"/><path d="M12 8h.01"/>',
"help": '<circle cx="12" cy="12" r="9"/><path d="M9.1 9a3 3 0 0 1 5.8 1c0 2-3 3-3 3"/><path d="M12 17h.01"/>',
"book": '<path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/><path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"/><path d="M9 7h7"/><path d="M9 11h5"/>',
"refresh": '<path d="M21 12a9 9 0 1 1-3-6.7"/><path d="M21 4v5h-5"/>',
"refresh-check": '<path d="M21 12a9 9 0 1 1-3-6.7"/><path d="M21 4v5h-5"/><path d="m9 12 2 2 4-4"/>',
"lock": '<rect x="4" y="10" width="16" height="11" rx="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3"/>',
"list-plus": '<path d="M4 6h11"/><path d="M4 12h8"/><path d="M4 18h8"/><path d="M18 10v8"/><path d="M14 14h8"/>',
"x-circle": '<circle cx="12" cy="12" r="9"/><path d="m15 9-6 6"/><path d="m9 9 6 6"/>',
"graduation": '<path d="M22 9 12 5 2 9l10 4 10-4z"/><path d="M6 11.5V16c0 1.5 2.7 3 6 3s6-1.5 6-3v-4.5"/>',
"graduation-alt": '<path d="M22 9 12 5 2 9l10 4 10-4z"/><path d="M6 11.5V16c0 1.5 2.7 3 6 3s6-1.5 6-3v-4.5"/><path d="M22 9v5"/>',
"camera": '<path d="M3 8a2 2 0 0 1 2-2h2l1.5-2h7L17 6h2a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><circle cx="12" cy="13" r="3.5"/>',
"gamepad": '<path d="M6 12h4"/><path d="M8 10v4"/><path d="M15.5 12h.01"/><path d="M18 10h.01"/><rect x="2" y="6" width="20" height="12" rx="4"/>',
"badge-check": '<path d="M12 2 14.5 4.5 18 4.7l.2 3.5L21 11l-2.8 2.8-.2 3.5-3.5.2L12 21l-2.5-2.5-3.5-.2-.2-3.5L3 11l2.8-2.8.2-3.5 3.5-.2z"/><path d="m9 12 2 2 4-4"/>',
"crosshair": '<circle cx="12" cy="12" r="8"/><path d="M12 2v4"/><path d="M12 18v4"/><path d="M2 12h4"/><path d="M18 12h4"/>',
"scan-search": '<path d="M3 7V5a2 2 0 0 1 2-2h2"/><path d="M17 3h2a2 2 0 0 1 2 2v2"/><path d="M21 17v2a2 2 0 0 1-2 2h-2"/><path d="M7 21H5a2 2 0 0 1-2-2v-2"/><circle cx="11" cy="11" r="3"/><path d="m14.5 14.5 2 2"/>',
"memory": '<rect x="3" y="7" width="18" height="10" rx="2"/><path d="M7 7V4"/><path d="M12 7V4"/><path d="M17 7V4"/><path d="M8 12h8"/>',
"select-all": '<rect x="3" y="3" width="18" height="18" rx="2"/><path d="m8 12 3 3 5-6"/>',
"eye": '<path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7-10-7-10-7z"/><circle cx="12" cy="12" r="3"/>',
"eye-off": '<path d="M10.7 5.1A9.9 9.9 0 0 1 12 5c6.4 0 10 7 10 7a16 16 0 0 1-2.4 3.2"/><path d="M6.3 6.3A16 16 0 0 0 2 12s3.6 7 10 7a9.7 9.7 0 0 0 4.5-1.1"/><path d="m3 3 18 18"/>',
"code": '<path d="m16 18 6-6-6-6"/><path d="m8 6-6 6 6 6"/>',
"puzzle": '<path d="M14 3a2 2 0 1 1 4 0v1h1a2 2 0 0 1 2 2v3h1a2 2 0 1 1 0 4h-1v3a2 2 0 0 1-2 2h-3v-1a2 2 0 1 0-4 0v1H6a2 2 0 0 1-2-2v-3H3a2 2 0 1 1 0-4h1V6a2 2 0 0 1 2-2h8z"/>',
"arrow-down-line": '<path d="M12 3v12"/><path d="m7 10 5 5 5-5"/><path d="M5 21h14"/>',
"upload": '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><path d="M12 15V3"/><path d="m7 8 5-5 5 5"/>',
"download": '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><path d="M12 3v12"/><path d="m7 10 5 5 5-5"/>',

# --- depurador y memoria ---
"play": '<path d="m6 4 14 8-14 8z"/>',
"play-circle": '<circle cx="12" cy="12" r="9"/><path d="m10 8 6 4-6 4z"/>',
"fast-forward": '<path d="m3 5 8 7-8 7z"/><path d="m13 5 8 7-8 7z"/>',
"step-into": '<path d="M12 3v10"/><path d="m8 9 4 4 4-4"/><circle cx="12" cy="19" r="2"/>',
"step-over": '<path d="M4 15a8 8 0 0 1 14-5"/><path d="M18 5v5h-5"/><circle cx="6" cy="19" r="2"/>',
"step-out": '<path d="M12 13V3"/><path d="m8 7 4-4 4 4"/><circle cx="12" cy="19" r="2"/>',
"breakpoint": '<circle cx="12" cy="12" r="7"/><circle cx="12" cy="12" r="3" fill="#D8D8D8" stroke="none"/>',
"pause": '<path d="M9 4v16"/><path d="M15 4v16"/>',
"thread": '<circle cx="6" cy="6" r="2.5"/><circle cx="6" cy="18" r="2.5"/><circle cx="18" cy="12" r="2.5"/><path d="M6 8.5v7"/><path d="M8.5 6H14a2 2 0 0 1 2 2v2"/>',
"list": '<path d="M8 6h13"/><path d="M8 12h13"/><path d="M8 18h13"/><path d="M3 6h.01"/><path d="M3 12h.01"/><path d="M3 18h.01"/>',
"list-checks": '<path d="M10 6h11"/><path d="M10 12h11"/><path d="M10 18h11"/><path d="m3 6 1.5 1.5L7 5"/><path d="m3 12 1.5 1.5L7 11"/><path d="m3 18 1.5 1.5L7 17"/>',
"follow": '<path d="M4 4v7a4 4 0 0 0 4 4h9"/><path d="m14 11 4 4-4 4"/>',
"back": '<path d="M19 12H5"/><path d="m11 18-6-6 6-6"/>',
"bookmark": '<path d="M18 21 12 17l-6 4V5a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2z"/>',
"bookmark-goto": '<path d="M17 20 12 17l-5 3V5a2 2 0 0 1 2-2h6a2 2 0 0 1 2 2z"/><path d="m19 9 3 3-3 3"/>',
"symbols": '<path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8z"/><path d="M14 3v5h5"/><path d="m10 13-2 2 2 2"/><path d="m14 13 2 2-2 2"/>',
"history": '<path d="M3 12a9 9 0 1 0 3-6.7"/><path d="M3 4v5h5"/><path d="M12 8v4l3 2"/>',
"fill": '<path d="M10 3 3 10a2 2 0 0 0 0 2.8l6.2 6.2a2 2 0 0 0 2.8 0L19 12z"/><path d="m7 6 6 6"/><path d="M20 15s2 2.5 2 3.8a2 2 0 1 1-4 0C18 17.5 20 15 20 15z"/>',
"wrench": '<path d="M14.7 6.3a4 4 0 0 0 5 5l-9.4 9.4a2.8 2.8 0 0 1-4-4z"/>',
"inject": '<rect x="3" y="8" width="12" height="8" rx="2"/><path d="M15 12h6"/><path d="m18 9 3 3-3 3"/>',
"diff": '<path d="M12 3v18"/><path d="M9 6H4a1 1 0 0 0-1 1v10a1 1 0 0 0 1 1h5"/><path d="M15 6h5a1 1 0 0 1 1 1v10a1 1 0 0 1-1 1h-5"/>',
"goto": '<circle cx="12" cy="12" r="9"/><path d="M9 12h6"/><path d="m12 9 3 3-3 3"/>',
"layers": '<path d="m12 2 9 5-9 5-9-5z"/><path d="m3 12 9 5 9-5"/><path d="m3 17 9 5 9-5"/>',
"activity": '<path d="M3 12h4l3-8 4 16 3-8h4"/>',
"brackets": '<path d="M8 4H6a2 2 0 0 0-2 2v4a2 2 0 0 1-2 2 2 2 0 0 1 2 2v4a2 2 0 0 0 2 2h2"/><path d="M16 4h2a2 2 0 0 1 2 2v4a2 2 0 0 0 2 2 2 2 0 0 0-2 2v4a2 2 0 0 1-2 2h-2"/>',
"ban": '<circle cx="12" cy="12" r="9"/><path d="m5.6 5.6 12.8 12.8"/>',
"hammer": '<path d="m15 12-8.4 8.4a2 2 0 0 1-2.8-2.8L12 9"/><path d="M17.6 2.4 22 6.8l-3 3-1.5-1.5-3 3-3-3 3-3L13 4z"/>',
"page-protect": '<rect x="4" y="3" width="16" height="18" rx="2"/><path d="M12 8v3"/><rect x="9" y="11" width="6" height="5" rx="1"/>',
"hash": '<path d="M4 9h16"/><path d="M4 15h16"/><path d="M10 3 8 21"/><path d="M16 3l-2 18"/>',
"ghost": '<path d="M12 3a7 7 0 0 0-7 7v11l3-2 2 2 2-2 2 2 2-2 3 2V10a7 7 0 0 0-7-7z"/><path d="M9.5 10h.01"/><path d="M14.5 10h.01"/>',
"spider": '<circle cx="12" cy="12" r="3"/><path d="M12 9V4"/><path d="m9.5 10-4-3"/><path d="m14.5 10 4-3"/><path d="M9 13H3"/><path d="M15 13h6"/><path d="m10 15-3 4"/><path d="m14 15 3 4"/>',
"paging": '<rect x="3" y="4" width="7" height="7" rx="1"/><rect x="14" y="4" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/>',
"table": '<rect x="3" y="4" width="18" height="16" rx="2"/><path d="M3 10h18"/><path d="M9 10v10"/>',
"filter": '<path d="M3 5h18l-7 8v6l-4 2v-8z"/>',
"map": '<path d="m3 6 6-3 6 3 6-3v15l-6 3-6-3-6 3z"/><path d="M9 3v15"/><path d="M15 6v15"/>',
"map-2": '<path d="m3 6 6-3 6 3 6-3v15l-6 3-6-3-6 3z"/><path d="M9 3v15"/><path d="M15 6v15"/><path d="M19 2v4"/>',
"dissect": '<rect x="3" y="3" width="18" height="18" rx="2"/><path d="M3 9h18"/><path d="M9 9v12"/><path d="M12 13h6"/><path d="M12 17h6"/>',
"cave": '<path d="M4 20V9a8 8 0 0 1 16 0v11"/><path d="M9 20v-5a3 3 0 0 1 6 0v5"/>',
"microscope": '<path d="M6 18h12"/><path d="M10 18V9a3 3 0 0 1 6 0v9"/><path d="M8 9h2"/><path d="M14 4h2"/><path d="M4 21h16"/>',
"stacktrace": '<path d="M4 6h16"/><path d="M7 11h13"/><path d="M10 16h10"/><path d="M4 11h.01"/><path d="M7 16h.01"/>',
"debug-strings": '<path d="M21 15a2 2 0 0 1-2 2H8l-4 4V5a2 2 0 0 1 2-2h13a2 2 0 0 1 2 2z"/><path d="M8 9h8"/><path d="M8 13h5"/>',
"events": '<path d="M13 2 4 14h7l-1 8 9-12h-7z"/>',
"dissect-window": '<rect x="3" y="4" width="18" height="16" rx="2"/><path d="M3 9h18"/><path d="M9 9v11"/><path d="M12 13h5"/>',
"pe-headers": '<path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8z"/><path d="M14 3v5h5"/><circle cx="12" cy="15" r="2"/><path d="M12 12v-1"/><path d="M12 19v-1"/>',
"regions": '<rect x="3" y="4" width="18" height="4" rx="1"/><rect x="3" y="10" width="18" height="4" rx="1"/><rect x="3" y="16" width="18" height="4" rx="1"/>',
"load-trace": '<path d="M3 7V5a2 2 0 0 1 2-2h4l2 3h6a2 2 0 0 1 2 2v2"/><path d="M3 12v6a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-6"/><path d="M12 11v5"/><path d="m9 13 3 3 3-3"/>',
"strings": '<path d="M6 8V6h12v2"/><path d="M12 6v12"/><path d="M9 18h6"/>',
"functions": '<path d="M8 21c1.5 0 2-1 2-3V6c0-2 .5-3 2-3"/><path d="M6 12h8"/><path d="M15 10.5 21 17"/><path d="m21 10.5-6 6.5"/>',
"image": '<rect x="3" y="4" width="18" height="16" rx="2"/><circle cx="8.5" cy="9.5" r="1.5"/><path d="m21 16-5-5-6 6-3-3-4 4"/>',
"allocate": '<rect x="3" y="6" width="12" height="12" rx="2"/><path d="M18 9v6"/><path d="M15 12h6"/>',
"terminal": '<rect x="3" y="4" width="18" height="16" rx="2"/><path d="m7 9 3 3-3 3"/><path d="M13 15h4"/>',

# --- disenador de formularios ---
"w-button": '<rect x="3" y="8" width="18" height="8" rx="2"/><path d="M8 12h8"/>',
"w-label": '<path d="M5 7h14"/><path d="M12 7v10"/><path d="M9 17h6"/>',
"w-panel": '<rect x="3" y="4" width="18" height="16" rx="2"/>',
"w-memo": '<rect x="3" y="4" width="18" height="16" rx="2"/><path d="M7 9h10"/><path d="M7 13h10"/><path d="M7 17h5"/>',
"w-edit": '<rect x="3" y="8" width="18" height="8" rx="2"/><path d="M7 10v4"/>',
"w-toggle": '<rect x="2" y="7" width="20" height="10" rx="5"/><circle cx="16" cy="12" r="3"/>',
"w-checkbox": '<rect x="4" y="4" width="16" height="16" rx="2"/><path d="m8 12 3 3 5-6"/>',
"w-groupbox": '<path d="M3 8v11a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V8"/><path d="M3 8h5"/><path d="M14 8h7"/>',
"w-radiogroup": '<rect x="3" y="4" width="18" height="16" rx="2"/><circle cx="8" cy="10" r="1.5"/><circle cx="8" cy="15" r="1.5"/><path d="M12 10h5"/><path d="M12 15h5"/>',
"w-listbox": '<rect x="3" y="4" width="18" height="16" rx="2"/><path d="M7 9h10"/><path d="M7 13h10"/><path d="M7 17h10"/>',
"w-combobox": '<rect x="3" y="8" width="18" height="8" rx="2"/><path d="m15 11 2 2 2-2"/>',
"w-timer": '<circle cx="12" cy="13" r="8"/><path d="M12 9v4l2.5 2.5"/><path d="M9 2h6"/>',
"w-progressbar": '<rect x="2" y="9" width="20" height="6" rx="3"/><path d="M5 12h7"/>',
"w-trackbar": '<path d="M3 12h18"/><circle cx="9" cy="12" r="3"/>',
"w-listview": '<rect x="3" y="4" width="18" height="16" rx="2"/><path d="M3 9h18"/><path d="M9 9v11"/>',
"w-splitter": '<path d="M12 3v18"/><path d="m8 9-3 3 3 3"/><path d="m16 9 3 3-3 3"/>',
"w-paintbox": '<rect x="3" y="4" width="18" height="16" rx="2"/><path d="m7 16 4-5 3 3 3-4"/>',
"w-treeview": '<path d="M5 4v14a2 2 0 0 0 2 2h3"/><path d="M5 11h5"/><path d="M14 4h5"/><path d="M13 11h6"/><path d="M13 20h6"/>',
"w-pagecontrol": '<path d="M3 8v11a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V8"/><path d="M3 8h7V4h6v4h5"/>',
"w-mainmenu": '<rect x="3" y="4" width="18" height="16" rx="2"/><path d="M3 9h18"/><path d="M6 6.5h3"/><path d="M11 6.5h3"/>',
"w-popupmenu": '<rect x="6" y="6" width="14" height="14" rx="2"/><path d="M10 11h6"/><path d="M10 15h6"/><path d="M4 4h.01"/>',
"w-calendar": '<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M3 10h18"/><path d="M8 3v4"/><path d="M16 3v4"/>',
"w-finddialog": '<rect x="3" y="4" width="18" height="16" rx="2"/><circle cx="11" cy="12" r="3"/><path d="m15 16-1.5-1.5"/>',
"w-seldir": '<path d="M3 7V5a2 2 0 0 1 2-2h4l2 3h6a2 2 0 0 1 2 2v2"/><path d="M3 12v6a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-6"/><path d="m9 15 2 2 4-4"/>',
"w-radiobutton": '<circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="3" fill="#D8D8D8" stroke="none"/>',
"w-scrollbox": '<rect x="3" y="4" width="18" height="16" rx="2"/><path d="M18 8v8"/><path d="m16 10 2-2 2 2"/><path d="m16 14 2 2 2-2"/>',
"w-checklistbox": '<rect x="3" y="4" width="18" height="16" rx="2"/><path d="m6 9 1.5 1.5L10 8"/><path d="m6 15 1.5 1.5L10 14"/><path d="M13 10h5"/><path d="M13 16h5"/>',
"w-vtree": '<path d="M5 4v14a2 2 0 0 0 2 2h3"/><path d="M5 11h5"/><path d="M14 4h5"/><path d="M13 11h6"/><path d="M13 20h6"/><path d="M19 7h.01"/>',
"w-none": '<path d="m5 5 14 14"/><path d="M19 5 5 19"/>',

# --- estructuras ---
"struct-new": '<rect x="3" y="3" width="18" height="18" rx="2"/><path d="M3 9h18"/><path d="M12 13v5"/><path d="M9.5 15.5h5"/>',
"struct-import": '<path d="M12 3v10"/><path d="m8 9 4 4 4-4"/><path d="M4 17v2a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-2"/>',
"struct-export": '<path d="M12 13V3"/><path d="m8 7 4-4 4 4"/><path d="M4 17v2a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-2"/>',
"expand": '<path d="m7 9 5 5 5-5"/><path d="M4 4h16"/><path d="M4 20h16"/>',
"collapse": '<path d="m7 14 5-5 5 5"/><path d="M4 4h16"/><path d="M4 20h16"/>',
"autoguess": '<path d="M12 3a6 6 0 0 0-4 10.5V17h8v-3.5A6 6 0 0 0 12 3z"/><path d="M10 21h4"/>',
"gaps": '<path d="M3 12h4"/><path d="M10 12h4"/><path d="M17 12h4"/><path d="M3 6h18"/><path d="M3 18h18"/>',
"relations": '<circle cx="6" cy="6" r="2.5"/><circle cx="18" cy="6" r="2.5"/><circle cx="12" cy="18" r="2.5"/><path d="m7.5 8 3.5 7.5"/><path d="m16.5 8-3.5 7.5"/>',
"offsets": '<path d="M4 7h16"/><path d="M4 12h10"/><path d="M4 17h16"/><path d="m18 10 3 2-3 2"/>',
}


MAPS = {
 'mfImageList': {          # ventana principal
   0:'trash', 1:'arrow-down-line', 2:'settings', 3:'folder-open', 4:'save',
   5:'save-as', 6:'folder-input', 7:'scan-search', 8:'tab-plus',
   9:'file-plus', 10:'book', 11:'info', 12:'app-window', 13:'refresh',
   14:'exit', 15:'refresh-check', 17:'pencil', 18:'help', 19:'lock',
   20:'list-plus', 21:'copy', 22:'x-circle', 23:'graduation',
   24:'graduation-alt', 25:'camera', 26:'gamepad', 27:'badge-check',
   28:'scissors', 29:'clipboard', 30:'crosshair', 31:'memory', 32:'undo',
   33:'select-all', 34:'eye', 35:'palette', 36:'code', 37:'puzzle',
 },
 'mvImageList': {          # visor de memoria
   0:'play', 1:'step-into', 2:'step-over', 3:'step-out', 4:'breakpoint',
   5:'new-window', 6:'pencil', 7:'allocate', 8:'terminal', 9:'search',
   10:'search-replace', 11:'pause', 12:'thread', 13:'list',
   14:'list-checks', 15:'copy', 16:'list-plus', 17:'follow', 18:'back',
   19:'bookmark', 20:'bookmark-goto', 21:'symbols', 22:'download',
   23:'upload', 24:'file-text', 25:'eye', 26:'history', 27:'fill',
   28:'wrench', 29:'inject', 30:'diff', 31:'clipboard', 32:'x-circle',
   35:'goto', 36:'layers', 38:'activity', 39:'eye-off', 40:'sliders',
   41:'brackets', 42:'ban', 43:'hammer', 46:'page-protect', 48:'hash',
   50:'ghost', 51:'spider', 53:'paging', 54:'table', 55:'filter',
   56:'map', 57:'map-2', 58:'dissect', 59:'cave', 60:'microscope',
   64:'stacktrace', 66:'debug-strings', 68:'events', 69:'dissect-window',
   70:'pe-headers', 71:'regions', 72:'load-trace', 73:'strings',
   74:'functions', 75:'image', 76:'strings', 77:'fast-forward',
   78:'play-circle',
 },
 'ImageList1': {           # disenador de formularios
   0:'w-none', 1:'w-button', 2:'w-label', 3:'w-panel', 4:'image',
   5:'w-memo', 6:'w-edit', 7:'w-toggle', 8:'w-checkbox', 9:'w-groupbox',
   10:'w-radiogroup', 11:'w-listbox', 12:'w-combobox', 13:'w-timer',
   14:'folder-open', 15:'w-savedialog', 16:'w-progressbar',
   17:'w-trackbar', 18:'w-listview', 19:'w-splitter', 20:'w-paintbox',
   21:'w-treeview', 22:'w-pagecontrol', 23:'w-mainmenu', 24:'w-popupmenu',
   25:'w-calendar', 26:'w-finddialog', 27:'w-seldir', 28:'w-radiobutton',
   29:'w-scrollbox', 30:'w-checklistbox', 31:'w-button', 32:'w-vtree',
 },
 'sdImageList': {          # estructuras
   0:'new-window', 1:'list-plus', 2:'trash', 3:'settings', 4:'save',
   5:'pencil', 6:'back', 7:'copy', 8:'clipboard', 9:'relations',
   10:'struct-import', 11:'struct-export', 12:'expand', 13:'struct-new',
   15:'memory', 16:'offsets', 17:'autoguess', 18:'gaps', 19:'collapse',
   20:'goto',
 },
 'aaImageList': {          # auto assembler
   0:'new-window', 1:'folder-open', 2:'save', 3:'save-as', 4:'close',
   5:'palette', 6:'search', 7:'copy', 8:'clipboard', 9:'scissors',
   10:'undo', 11:'search-replace', 12:'tab-plus', 13:'rename',
   14:'check-syntax', 15:'move-right', 16:'move-left',
 },
 'leImageList': {          # motor Lua
   0:'new-window', 1:'folder-open', 2:'save', 3:'save-as', 4:'trash',
   5:'copy', 6:'clipboard', 7:'scissors', 8:'search', 9:'undo',
   10:'search-replace', 11:'redo', 12:'palette',
 },
 'ilLuaDebug': {           # barra de depuracion de Lua
   0:'play', 1:'step-into', 2:'step-over', 3:'step-out', 4:'ban',
 },
}

# w-savedialog no esta en el catalogo aparte: reutiliza el disquete
C['w-savedialog'] = C['save']


def main():
    outroot, tmp = sys.argv[1], sys.argv[2]
    os.makedirs(tmp, exist_ok=True)
    total, faltan = 0, 0

    for listname, mapping in sorted(MAPS.items()):
        outdir = os.path.join(outroot, listname)
        os.makedirs(outdir, exist_ok=True)
        for idx, name in sorted(mapping.items()):
            paths = C.get(name)
            if paths is None:
                print('  !! falta el dibujo %r (%s:%d)' % (name, listname, idx))
                faltan += 1
                continue
            for s in SIZES:
                svg = os.path.join(tmp, '%s_%d_%d.svg' % (listname, idx, s))
                with open(svg, 'w', encoding='utf-8') as f:
                    f.write(hdr(stroke_for(s)) + paths + '</svg>')
                subprocess.run(['magick', '-background', 'none', '-density', '600',
                                svg, '-resize', '%dx%d' % (s, s),
                                '-define', 'png:color-type=6',
                                os.path.join(outdir, '%d_%d.png' % (idx, s))],
                               check=True, capture_output=True)
                total += 1
        print('  %-14s %3d iconos' % (listname, len(mapping)))

    print('\n%d archivos en %d listas%s' %
          (total, len(MAPS), (', %d sin dibujo' % faltan) if faltan else ''))


if __name__ == '__main__':
    main()
