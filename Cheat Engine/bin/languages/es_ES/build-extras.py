#!/usr/bin/env python3
"""Traduce los .po de los scripts Lua que acompanan a Cheat Engine.

Uso:
    python3 build-extras.py ..

Son archivos aparte del .po principal: cada script de la carpeta autorun
lleva el suyo, y sin ellos entradas como "Save scan session" o "Load scan
session" salen en ingles aunque el resto de la interfaz este traducido.

Las plantillas estan sueltas en bin/languages/. Lo que no se traduce se deja
vacio y Cheat Engine muestra el original.
"""
import re, sys, io, os

T = {
# --- SaveSessions ---
"Open a process first": "Abre primero un proceso",
"Open a process first and do a scan": "Abre primero un proceso y haz un escaneo",
"Cheat Engine Scan files": "Archivos de escaneo de Cheat Engine",
"Save scan session": "Guardar la sesión de escaneo",
"Load scan session": "Cargar una sesión de escaneo",

# --- patchscan ---
"Not a valid executable": "No es un ejecutable válido",
"Not a valid windows executable": "No es un ejecutable de Windows válido",
"This type of module is currently not supported": "Este tipo de módulo no se admite por ahora",
"Compare error. ": "Error al comparar. ",
"Module List": "Lista de módulos",
"Select the modules to scan for patches. Hold shift/ctrl to select multiple modules":
    "Selecciona los módulos en los que buscar parches. Mantén Mayús o Ctrl para elegir varios",
"  OK  ": "  Aceptar  ",
"Cancel": "Cancelar",
"Scanning: %s": "Escaneando: %s",
"Error in ": "Error en ",
"Patch list": "Lista de parches",
"Address": "Dirección",
"Original": "Original",
"Patched": "Parcheado",
"Restore with original": "Restaurar el original",
"Reapply patch": "Volver a aplicar el parche",
"Scan for patches": "Buscar parches",

# --- pseudocodediagram ---
"File": "Archivo",
"Load from file": "Cargar desde archivo",
"Select the file you wish to open": "Selecciona el archivo que quieres abrir",
"Diagram files (*.CEDIAG )|*.CEDIAG": "Archivos de diagrama (*.CEDIAG )|*.CEDIAG",
"Save to file": "Guardar en un archivo",
"Fill in the filename you wish to save this diagram as":
    "Indica con qué nombre quieres guardar este diagrama",
"Save diagram to image": "Guardar el diagrama como imagen",
"Fill in the filename you wish to save this diagram image":
    "Indica con qué nombre quieres guardar la imagen del diagrama",
"PNG files (*.PNG )|*.PNG": "Archivos PNG (*.PNG )|*.PNG",
"Close": "Cerrar",
"Display": "Ver",
"Show path from Ultimap1/2 or Codefilter":
    "Mostrar la ruta desde Ultimap1/2 o el filtro de código",
"Show path from tracer window": "Mostrar la ruta desde la ventana de traza",
"Tracer starting at %8x (%s)": "Traza que empieza en %8x (%s)",
"Tracer paths": "Rutas de traza",
"Which tracer window shall be used?": "¿Qué ventana de traza quieres usar?",
"No tracerform with results visible": "No hay ninguna ventana de traza con resultados",
"View": "Vista",
"Zoom": "Zoom",
"Zoom in": "Acercar",
"Zoom out": "Alejar",
"Edit": "Editar",
"new header": "nueva cabecera",
"new block background color (0xBBGGRR)": "nuevo color de fondo del bloque (0xBBGGRR)",
"Sources list": "Lista de orígenes",
"Destinations list": "Lista de destinos",
"Block editor": "Editor de bloques",
"OK": "Aceptar",
"Go to source": "Ir al origen",
"Go to destination": "Ir al destino",
"Remove all points": "Quitar todos los puntos",
"Edit block header": "Editar la cabecera del bloque",
"Edit block color": "Editar el color del bloque",
"List sources": "Listar los orígenes",
"List destinations": "Listar los destinos",
"Edit annotation color": "Editar el color de la anotación",
"Delete annotation": "Eliminar la anotación",
"Create annotation": "Crear una anotación",
"[Diagram info]": "[Información del diagrama]",
" Function start: 0x%X": " Inicio de la función: 0x%X",
" Function stop: 0x%X": " Fin de la función: 0x%X",
" Diagram blocks count: %d": " Número de bloques del diagrama: %d",

# --- CeShare ---
"Cheat Browser": "Explorador de trucos",
"Processname:": "Nombre del proceso:",
"Title": "Título",
"Author": "Autor",
"Public": "Público",
"Score": "Puntuación",
"Version independent": "Independiente de la versión",
"% Match": "% de coincidencia",
"    Load    ": "    Cargar    ",
"Add/View Comments": "Añadir o ver comentarios",
}

_ESC = {'n': '\n', 't': '\t', 'r': '\r', '"': '"', '\\': '\\'}
_LINE = re.compile(r'^\s*"((?:[^"\\]|\\.)*)"\s*$')


def unescape(s):
    return re.sub(r'\\(.)', lambda m: _ESC.get(m.group(1), '\\' + m.group(1)), s)


def escape(s):
    s = s.replace('\\', '\\\\').replace('"', '\\"')
    return s.replace('\n', '\\n').replace('\t', '\\t').replace('\r', '\\r')


def read_field(lines, start, keyword):
    m = re.match(r'^%s\s+"((?:[^"\\]|\\.)*)"\s*$' % keyword, lines[start])
    if not m:
        return None
    parts = [m.group(1)]
    i = start + 1
    while i < len(lines) and _LINE.match(lines[i]):
        parts.append(_LINE.match(lines[i]).group(1))
        i += 1
    return unescape(''.join(parts))


def field_of(block, keyword):
    lines = block.split('\n')
    for i, l in enumerate(lines):
        if l.startswith(keyword):
            return read_field(lines, i, keyword)
    return None


def set_msgstr(block, texto):
    lines = block.split('\n')
    out, i = [], 0
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


def build(src, dst):
    #las plantillas sueltas traen BOM y saltos CRLF, que rompen el parseo
    txt = io.open(src, encoding='utf-8-sig', errors='replace').read()
    txt = txt.replace('\r\n', '\n').replace('\r', '\n')
    out, n = [], 0
    for b in txt.split('\n\n'):
        if not b.strip():
            continue
        key = field_of(b, 'msgid')
        if not key:            #cabecera del .po
            out.append(b)
            continue
        tr = T.get(key, '')
        if tr:
            n += 1
        out.append(set_msgstr(b, tr))
    # NO se anade cabecera: loadPOFile, el parser de los scripts Lua, la trata
    # como una entrada mas y la concatena con la primera traduccion, dejando
    # "Content-Type: text/plain..." pegado al texto en el menu. Las plantillas
    # originales tampoco la traen. msgfmt avisa del charset, pero es UTF-8.
    io.open(dst, 'w', encoding='utf-8', newline='\n').write('\n\n'.join(out) + '\n')
    return n


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else '..'
    here = os.path.dirname(os.path.abspath(__file__))

    for name in ('SaveSessions', 'patchscan', 'pseudocodediagram', 'CeShare'):
        src = os.path.join(root, name + '.po')
        if not os.path.exists(src):
            print('%-20s plantilla no encontrada' % name)
            continue
        n = build(src, os.path.join(here, name + '.po'))
        print('%-20s %d traducidas' % (name, n))


if __name__ == '__main__':
    main()
