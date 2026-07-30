#!/usr/bin/env python3
"""Genera es_ES/cheatengine-x86_64.po.

Uso:
    python3 build-es_ES.py ../de_DE/cheatengine-x86_64.po \
                           ../cl_CL/cheatengine-x86_64.po \
                           cheatengine-x86_64.po

Capas, de menor a mayor prioridad:
  1. cl_CL   -> base de cobertura (99% traducido, pero escrito sin tildes)
  2. ACENTOS -> repone las tildes que le faltan al pack latino
  3. T       -> traducciones revisadas a mano; corrigen los errores de cl_CL
                (Fast Scan -> "1erEscaneo", Not -> "Nada", ...)
  4. EXTRA   -> cadenas de esta version que la plantilla no trae

Los msgid salen de la plantilla de de_DE, que es la que viene en el repo.
Lo que no se traduce se deja vacio y Cheat Engine muestra el original.
"""
import re, sys, io

# --- capa 3: traducciones revisadas -----------------------------------------
T = {
# ventana principal / escaneo
"First Scan": "Primer escaneo",
"New Scan": "Nuevo escaneo",
"Next Scan": "Siguiente escaneo",
"Undo Scan": "Deshacer escaneo",
"Scan": "Escanear",
"Memory View": "Ver memoria",
"Add Address Manually": "Añadir dirección manualmente",
"No Process Selected": "Ningún proceso seleccionado",
"Value": "Valor",
"Value:": "Valor:",
"Text:": "Texto:",
# lblScanType ancla su borde derecho al combo ScanType, que a su vez va anclado
# a Panel9, asi que el hueco es fijo y no se puede ensanchar desde init.lua: la
# LCL recalcula el ancho al instante. "Tipo de escaneo" ocupa 85px y se sale de
# Panel5. Se acorta a 12 caracteres, menos que "Tipo de valor" (13), que si cabe.
"Scan Type": "Tipo escaneo",
"Value Type": "Tipo de valor",
"Exact Value": "Valor exacto",
"Bigger than...": "Mayor que...",
"Smaller than...": "Menor que...",
"Value between...": "Valor entre...",
"Unknown initial value": "Valor inicial desconocido",
"Increased value": "Valor aumentado",
"Increased value by ...": "Valor aumentado en ...",
"Decreased value": "Valor disminuido",
"Decreased value by ...": "Valor disminuido en ...",
"Changed value": "Valor modificado",
"Unchanged value": "Valor sin cambios",
"Memory Scan Options": "Opciones de escaneo de memoria",
"Start": "Inicio",
"Stop": "Fin",
"Writable": "Escribible",
"Executable": "Ejecutable",
"CopyOnWrite": "Copia al escribir",
"Fast Scan": "Escaneo rápido",
"Alignment": "Alineación",
"Last Digits": "Últimos dígitos",
"Pause the game while scanning": "Pausar el juego durante el escaneo",
"Enable Speedhack": "Activar speedhack",
"Unrandomizer": "Desaleatorizador",
"Lua formula": "Fórmula Lua",
"Not": "No",
"Hex": "Hex",
"Hexadecimal": "Hexadecimal",
"Decimal": "Decimal",
"All": "Todo",
"Found:": "Encontrados:",
"Found %d": "Encontrados %d",
"Physical Memory": "Memoria física",
"Safer memory access": "Acceso a memoria más seguro",
"Terminating scan...": "Cancelando escaneo...",
"Scan error:%s": "Error de escaneo: %s",
"Scanresult": "Resultado del escaneo",
"Save scan results": "Guardar resultados del escaneo",
"Saved scan results": "Resultados guardados",
"Compare to first/saved scan": "Comparar con el primero/guardado",
"Comparing to %s": "Comparando con %s",
"Previous": "Anterior",
"Previous value list": "Lista de valores anteriores",
"First": "Primero",
"Modified": "Modificado",
"Saved": "Guardado",
"Save to disk": "Guardar en disco",
"Current process": "Proceso actual",
"Groups": "Grupos",
"Group %s": "Grupo %s",
"Remove from group ": "Quitar del grupo ",
"Custom LUA type": "Tipo LUA personalizado",
"Custom Type Name": "Nombre del tipo personalizado",
"Advanced Options": "Opciones avanzadas",

# lista de direcciones
"Active": "Activo",
"Description": "Descripción",
"Address": "Dirección",
"Type": "Tipo",
"Change value": "Cambiar valor",
"Change this value to:": "Cambiar este valor a:",
"Change these values to:": "Cambiar estos valores a:",
"Change the description to:": "Cambiar la descripción a:",
"Change script": "Cambiar script",
"Edit addresses": "Editar direcciones",
"Delete this address": "Eliminar esta dirección",
"Delete these addresses": "Eliminar estas direcciones",
"Remove selected address": "Quitar la dirección seleccionada",
"Remove selected addresses": "Quitar las direcciones seleccionadas",
"Recalculate address": "Recalcular dirección",
"Recalculate all addresses": "Recalcular todas las direcciones",
"Recalculate selected addresses": "Recalcular las direcciones seleccionadas",
"Freeze the address in this list": "Congelar la dirección de esta lista",
"Freeze all addresses in this list": "Congelar todas las direcciones de esta lista",
"Enable Cheat": "Activar truco",
"Disable Cheat": "Desactivar truco",
"This address is already in the list": "Esta dirección ya está en la lista",
"One or more addresses where already in the list": "Una o más direcciones ya estaban en la lista",
"Show as decimal": "Mostrar en decimal",
"Show as hexadecimal": "Mostrar en hexadecimal",
"Show as binary": "Mostrar en binario",
"Show as decimal value": "Mostrar como valor decimal",
"Show as hexadecimal value": "Mostrar como valor hexadecimal",
"Set a hotkey": "Asignar un atajo",
"Set hotkeys": "Asignar atajos",
"Set/Change hotkeys": "Asignar/cambiar atajos",
"Search for text": "Buscar texto",
"Search for this array": "Buscar esta secuencia",

# depuracion / opcodes
"Find out what accesses this pointer": "Averiguar qué accede a este puntero",
"Find out what writes this pointer": "Averiguar qué escribe en este puntero",
"Find what accesses the address pointed at by this pointer":
    "Averiguar qué accede a la dirección apuntada por este puntero",
"Find what writes the address pointed at by this pointer":
    "Averiguar qué escribe en la dirección apuntada por este puntero",
"The following opcodes accessed the selected address":
    "Los siguientes opcodes accedieron a la dirección seleccionada",
"The following opcodes changed the selected address":
    "Los siguientes opcodes modificaron la dirección seleccionada",
"The following opcodes read from the selected address":
    "Los siguientes opcodes leyeron de la dirección seleccionada",
"Force recheck symbols": "Forzar recomprobación de símbolos",
"Force termination": "Forzar cierre",

# dialogos y mensajes
"Cancel": "Cancelar",
"Delete": "Eliminar",
"Rename": "Renombrar",
"Rename file": "Renombrar archivo",
"Error": "Error",
"CE Error:": "Error de CE:",
"Unspecified error": "Error no especificado",
"Are you sure?": "¿Seguro?",
"Are you sure you want to delete %s?": "¿Seguro que quieres eliminar %s?",
"Are you sure you want to delete this form?": "¿Seguro que quieres eliminar este formulario?",
"Are you sure you want to delete all addresses?": "¿Seguro que quieres eliminar todas las direcciones?",
"Are you sure you want to erase the data in the current table?":
    "¿Seguro que quieres borrar los datos de la tabla actual?",
"You haven't saved your last changes yet. Save Now?":
    "Aún no has guardado los últimos cambios. ¿Guardar ahora?",
"Do you want to go to the Cheat Engine website?": "¿Quieres ir a la web de Cheat Engine?",
"Click here to go to the Cheat Engine homepage": "Haz clic aquí para ir a la web de Cheat Engine",
"Do you want to try out the tutorial?": "¿Quieres probar el tutorial?",
"Which language do you wish to use?": "¿Qué idioma quieres usar?",
"Language": "Idioma",
"Empty Recent Files List": "Vaciar la lista de archivos recientes",
"Give the new filename": "Indica el nuevo nombre de archivo",
"Give the new value for the selected address(es)":
    "Indica el nuevo valor para la(s) dirección(es) seleccionada(s)",
"What do you want the groupname to be?": "¿Qué nombre quieres para el grupo?",
"What name do you want to give to these scanresults?":
    "¿Qué nombre quieres dar a estos resultados?",
"What will be the new name for this tab?": "¿Cuál será el nuevo nombre de esta pestaña?",
"Select the saved results you wish to use": "Selecciona los resultados guardados que quieres usar",
"Select the saved scan result from the list below":
    "Selecciona el resultado guardado de la lista de abajo",
"Select the saved scan result to delete from the list below":
    "Selecciona el resultado guardado que quieres eliminar de la lista de abajo",
"This will close the current process. Are you sure you want to do this?":
    "Esto cerrará el proceso actual. ¿Seguro que quieres hacerlo?",
"Do you really want to go back to the results of the previous scan?":
    "¿Seguro que quieres volver a los resultados del escaneo anterior?",
"Do you wish to merge the current table with this table?":
    "¿Quieres combinar la tabla actual con esta tabla?",
"Load the associated table? (%s)": "¿Cargar la tabla asociada? (%s)",
"Keep the current address list/code list?":
    "¿Mantener la lista de direcciones/código actual?",
"There are more pointers selected. Do you want to change them as well?":
    "Hay más punteros seleccionados. ¿Quieres cambiarlos también?",
"Do you want to add a '0'-terminator at the end?":
    "¿Quieres añadir un terminador '0' al final?",
"Do you want a header with address support ?":
    "¿Quieres una cabecera con soporte de direcciones?",
"Do you want to protect this trainer file from editing?":
    "¿Quieres proteger este trainer contra edición?",
"Info about this table:": "Información sobre esta tabla:",
"Lua script: Cheat Table": "Script Lua: tabla de trucos",
"Generate groupscan command": "Generar comando de escaneo por grupos",
"Error while opening this process": "Error al abrir este proceso",
"Unable to scan. Fix your scan settings and restart Cheat Engine":
    "No se puede escanear. Corrige los ajustes de escaneo y reinicia Cheat Engine",
"This is not a valid notation": "Esta notación no es válida",
"This is not an valid value": "Este valor no es válido",
" is not a valid binary notation!": " no es una notación binaria válida",
"%s is not a valid speed": "%s no es una velocidad válida",
"%s is not a valid xml name": "%s no es un nombre xml válido",
"Invalid start address: %s": "Dirección de inicio no válida: %s",
"Invalid stop address: %s": "Dirección de fin no válida: %s",
"The text you entered isn't the same size as the original. Continue?":
    "El texto introducido no tiene el mismo tamaño que el original. ¿Continuar?",
"Not the same size!": "Tamaño distinto",
"failed to load": "no se pudo cargar",
"groupscan data invalid": "datos de escaneo por grupos no válidos",
"dbvm_watch failed": "dbvm_watch falló",
"Failure setting the debug privilege. Debugging may be limited.":
    "No se pudo obtener el privilegio de depuración. La depuración puede ser limitada.",
"Failure setting the load driver privilege. Debugging may be limited.":
    "No se pudo obtener el privilegio de carga de controladores. La depuración puede ser limitada.",
"Failure setting the CreateGlobal privilege.":
    "No se pudo obtener el privilegio CreateGlobal.",
"Failure setting the SeTcbPrivilege privilege. Debugging may be limited.":
    "No se pudo obtener el privilegio SeTcbPrivilege. La depuración puede ser limitada.",
"This button will force cancel a scan. Expect memory leaks":
    "Este botón cancela el escaneo a la fuerza. Es previsible que haya fugas de memoria",
"brings Cheat Engine to front": "trae Cheat Engine al frente",
"will hide all windows": "ocultará todas las ventanas",
"will hide the foreground window": "ocultará la ventana en primer plano",
"Restore and show": "Restaurar y mostrar",
"and": "y",
"shown": "mostrado",
"at least xx%": "al menos xx%",
"between %": "entre %",
"Value %": "Valor %",
"<busy>": "<ocupado>",
"<Processing>": "<Procesando>",
"<File in use>": "<Archivo en uso>",
"EXPIRED": "CADUCADO",
}

# Segunda tanda: cadenas que cl_CL no cubria. Se omiten a proposito los
# nombres de componentes (Panel1, pnlExample...), las teclas (F4..F9) y los
# terminos que no se traducen (DBVM, CR3, FPU, XMM, ARM, X86, Lua, JMP, PID).
T.update({
# --- estructuras y disecciones ---
"Structure Compare": "Comparar estructuras",
"Guess Field Types": "Deducir tipos de campo",
"Structure Name:": "Nombre de la estructura:",
"Structure name": "Nombre de la estructura",
"New Structure": "Nueva estructura",
"Symbol structures": "Estructuras de símbolos",
"Manage structure list": "Gestionar lista de estructuras",
"Manage structurelist": "Gestionar lista de estructuras",
"Structures are being parsed": "Analizando estructuras",
"There are %d structures in this list": "Hay %d estructuras en esta lista",
"There are currently xxx structures in the database": "Actualmente hay xxx estructuras en la base de datos",
"Invalid structure pointerfile": "Archivo de punteros de estructura no válido",
"The structure got changed. Aborting": "La estructura ha cambiado. Cancelando",
"Create new structure from changed": "Crear estructura a partir de lo modificado",
"Create new structure from unchanged": "Crear estructura a partir de lo no modificado",
"Define new structure from debug data": "Definir estructura a partir de datos de depuración",
"Name the new structure": "Nombra la nueva estructura",
"Pointer to instance of %s": "Puntero a una instancia de %s",
"Use Auto Types If Available": "Usar tipos automáticos si están disponibles",
"Compare data/structures": "Comparar datos y estructuras",
"Open in dissect data/structure": "Abrir en disección de datos/estructura",
"Dissect data loaded": "Datos diseccionados cargados",
"Doubleclick to launch structure compare": "Doble clic para comparar estructuras",
"Reallign compare": "Realinear comparación",
"element compare size": "tamaño de comparación por elemento",
"Adjust children as well": "Ajustar también los hijos",
"Always hide children": "Ocultar siempre los hijos",
"Collapse all pointers": "Contraer todos los punteros",
"Also scan for negative offsets": "Buscar también desplazamientos negativos",

# --- lista de direcciones ---
"Address List": "Lista de direcciones",
"Address List (%d)": "Lista de direcciones (%d)",
"Load address list": "Cargar lista de direcciones",
"Save addresslist": "Guardar lista de direcciones",
"Add Address": "Añadir dirección",
"Delete addresses": "Eliminar direcciones",
"Delete selected addresses": "Eliminar las direcciones seleccionadas",
"Delete selected records": "Eliminar los registros seleccionados",
"Copy selected addresses": "Copiar las direcciones seleccionadas",
"Addresses only": "Solo direcciones",
"Add all in row to address list": "Añadir toda la fila a la lista de direcciones",
"Change all values in row": "Cambiar todos los valores de la fila",
"Are you sure you wish to delete these entries(s)?": "¿Seguro que quieres eliminar estas entradas?",
"Are you sure the erase the list?": "¿Seguro que quieres borrar la lista?",
"Copy this address to Clipboard": "Copiar esta dirección al portapapeles",
"Copy this value to Clipboard": "Copiar este valor al portapapeles",
"Copy value to clipboard": "Copiar el valor al portapapeles",
"Copy Code Address to Clipboard": "Copiar la dirección de código al portapapeles",
"Copy Symbol Name": "Copiar el nombre del símbolo",
"Change value of selected addresses back to previous/saved value":
    "Devolver las direcciones seleccionadas a su valor anterior o guardado",
"Do you wish to adjust memory records with relative addresses as well?":
    "¿Quieres ajustar también los registros con direcciones relativas?",

# --- escaneo ---
"Exact value": "Valor exacto",
"Delete scanresult": "Eliminar resultado del escaneo",
"Save results to file": "Guardar los resultados en un archivo",
"Doubleclick to show scanner/results": "Doble clic para ver el escáner y los resultados",
"Assembly Scan. Please wait": "Escaneando ensamblador. Espera",
"Please select something to scan or enter a custom range":
    "Selecciona algo que escanear o introduce un rango personalizado",
"Repeat scan delay": "Retardo entre escaneos",
"Repeats the unchanged value scan until it gets stopped":
    "Repite el escaneo de valores sin cambios hasta que se detenga",
"Set custom alignment": "Definir alineación personalizada",
"Alignsize must be greater than 0": "El tamaño de alineación debe ser mayor que 0",
"Custom range start": "Inicio del rango personalizado",
"Custom range stop": "Fin del rango personalizado",
"%s is an invalid range (xxxx-xxxx)": "%s no es un rango válido (xxxx-xxxx)",
"Are you sure you wish to remove the range %s?": "¿Seguro que quieres quitar el rango %s?",
"Max addresses shown :": "Máximo de direcciones mostradas:",
"Max addresses shown : 32": "Máximo de direcciones mostradas: 32",
"This lets you specify the maximum number of addresses to show per line":
    "Permite indicar cuántas direcciones se muestran como máximo por línea",
"This will result in 0 results as address %s appears multiple times":
    "Esto no dará resultados porque la dirección %s aparece varias veces",
"Commonality scanner": "Escáner de coincidencias",
"Scan for commonalities": "Buscar coincidencias",
"Find commonalities between addresses": "Buscar coincidencias entre direcciones",
"Scan for commonalities using the structure compare window":
    "Buscar coincidencias con la ventana de comparación de estructuras",
"Only find matching groups": "Buscar solo grupos coincidentes",
"Mark selection as group 1": "Marcar la selección como grupo 1",
"Mark selection as group 2 (Nothing means everything else)":
    "Marcar la selección como grupo 2 (vacío significa todo lo demás)",
"Invalid groups": "Grupos no válidos",
"Group 2": "Grupo 2",
"Please designate a group to at least some addresses":
    "Asigna un grupo al menos a algunas direcciones",
"There are no addresses left for group %d": "No quedan direcciones para el grupo %d",
"Group %d address %s (%s) is not valid": "La dirección %s del grupo %d (%s) no es válida",
"Reload the previous value list (Forgot value scan)":
    "Recargar la lista de valores anteriores (escaneo de valor olvidado)",
"Only show current \"compare to\" column": "Mostrar solo la columna «comparar con» actual",
"Show previous value column(s)": "Mostrar las columnas de valor anterior",
"'Compare To' header color": "Color de la cabecera «Comparar con»",
"Foundlist Customizer": "Personalizar la lista de resultados",
"Show static addresses using their static notation":
    "Mostrar las direcciones estáticas con su notación estática",
"S=Static D=Dynamic E=Executable": "S=Estática D=Dinámica E=Ejecutable",
"Static": "Estático",
"Dynamic": "Dinámico",
"All files (*.*)|*.*|Scan Data (*.scandata)|*.scandata":
    "Todos los archivos (*.*)|*.*|Datos de escaneo (*.scandata)|*.scandata",

# --- tipos de valor ---
"All Custom Types": "Todos los tipos personalizados",
"Change Type": "Cambiar tipo",
"Array of Byte": "Secuencia de bytes",
"Array Of Byte": "Secuencia de bytes",
"Byte (Hex)": "Byte (Hex)",
"2 Byte (Hex)": "2 bytes (Hex)",
"4 Byte (Hex)": "4 bytes (Hex)",
"8 Byte (Hex)": "8 bytes (Hex)",
"Byte: %s": "Byte: %s",
"2 Byte: %s": "2 bytes: %s",
"Multiline String": "Cadena multilínea",
"This type is not supported here": "Este tipo no se admite aquí",
"Pointer type not recognised: ": "Tipo de puntero no reconocido: ",
"The 'all' type includes": "El tipo «todo» incluye",
"1,2 or 4": "1, 2 o 4",
"Ignore value": "Ignorar valor",
"Normal value": "Valor normal",
"Unchanged": "Sin cambios",
"(was %s)": "(era %s)",
"Changes": "Cambios",
"Value Change": "Cambio de valor",
"Watch for changes": "Vigilar cambios",
"Stop watch for changes": "Dejar de vigilar cambios",
"Start watch": "Iniciar vigilancia",
"Cancel wait": "Cancelar espera",
"Are you sure you wish to wait %d seconds?": "¿Seguro que quieres esperar %d segundos?",
"Give the new value": "Indica el nuevo valor",

# --- depurador ---
"Toggle BP": "Alternar punto de interrupción",
"Toggle Breakpoint": "Alternar punto de interrupción",
"Toggle Breakpoint (F5)": "Alternar punto de interrupción (F5)",
"Remove breakpoint": "Quitar punto de interrupción",
"Breakpoint method": "Método de punto de interrupción",
"Software breakpoint": "Punto de interrupción por software",
"Set specific breakpoint type": "Definir un tipo de punto de interrupción concreto",
"Setting breakpoints": "Estableciendo puntos de interrupción",
"Kernelmode": "Modo kernel",
"Usermode": "Modo usuario",
"Kernelmode breaks (when possible)": "Interrupciones en modo kernel (cuando sea posible)",
"Step Into": "Entrar en",
"Step Into (F7)": "Entrar en (F7)",
"Step Out": "Salir de",
"Step Out - Execute till return": "Salir de: ejecutar hasta el retorno",
"(Step Out) Shift+F8": "(Salir de) Shift+F8",
"Step Over(F8)": "Saltar sobre (F8)",
"Step over rep instructions": "Saltar sobre las instrucciones rep",
"Run Till...": "Ejecutar hasta...",
"(Run Till...) F4": "(Ejecutar hasta...) F4",
"Run (F9)": "Ejecutar (F9)",
"Run Unhandled": "Ejecutar sin gestionar",
"Show debug toolbar": "Mostrar la barra de depuración",
"Hide toolbar": "Ocultar la barra de herramientas",
"Disable toolbar": "Desactivar la barra de herramientas",
"Debugger attach aborted": "Se ha cancelado la conexión del depurador",
"Break on unexpected exceptions": "Interrumpir ante excepciones inesperadas",
"When CE starts default behaviour for unexpected breakpoints":
    "Comportamiento al arrancar ante puntos de interrupción inesperados",
"Break when inside specific regions": "Interrumpir solo dentro de regiones concretas",
"Only in specified regions": "Solo en las regiones indicadas",
"Exception ignore list": "Lista de excepciones ignoradas",
"The following exceptions will be ignored": "Se ignorarán las siguientes excepciones",
"Manage exception code filter": "Gestionar el filtro de códigos de excepción",
"Manage exception region list": "Gestionar la lista de regiones de excepción",
"Add Exception ": "Añadir excepción ",
"Exception code": "Código de excepción",
"Exception Breakpoint (+1 instruction)": "Punto de interrupción por excepción (+1 instrucción)",
"Because of unhandled exception %s": "Por la excepción no gestionada %s",
"Follow in hexview when stepping": "Seguir en la vista hexadecimal al avanzar",
"Change page protection": "Cambiar la protección de página",
"Never change memory protection when editing":
    "No cambiar nunca la protección de memoria al editar",
"Restore Protection": "Restaurar la protección",
"Use windows debug symbols": "Usar los símbolos de depuración de Windows",
"Use Mac debugger": "Usar el depurador de Mac",
"Mac Debug": "Depuración en Mac",
"Inject DYLIB": "Inyectar DYLIB",
"Use thread for freeze": "Usar un hilo para congelar",
"Task Level": "Nivel de tarea",
"Thread level": "Nivel de hilo",
"Trace all processes": "Trazar todos los procesos",
"Targeted process only": "Solo el proceso seleccionado",
"Attach to current foreground process": "Conectar con el proceso en primer plano",
"Convert PID to decimal": "Convertir el PID a decimal",

# --- trazas ---
"New trace": "Nueva traza",
"Open trace for comparison": "Abrir una traza para comparar",
"Open tracefile reader": "Abrir el lector de archivos de traza",
"Debug: Process tracefile": "Depuración: procesar archivo de traza",
"Waiting for trace to start": "Esperando a que empiece la traza",
"From Trace": "Desde la traza",
"From File": "Desde archivo",
"From Disassembler": "Desde el desensamblador",
"From Unwind Info": "Desde la información de desenrollado",
"Start condition (Optional, LUA format)": "Condición de inicio (opcional, en formato LUA)",
"Stay inside initial module": "Permanecer dentro del módulo inicial",
"Ignore stackpointers": "Ignorar los punteros de pila",
"Do not trigger interrupts when full": "No lanzar interrupciones al llenarse",
"Max buffersize (entries)": "Tamaño máximo del búfer (entradas)",
"Saves a stacksnapshot of 4KB for each logged entry":
    "Guarda una instantánea de pila de 4 KB por cada entrada registrada",
"Log whole page instead of address range":
    "Registrar la página entera en vez del rango de direcciones",
"Log FPU data": "Registrar los datos de la FPU",
"Log stack": "Registrar la pila",
"Missed %d entries due to a too small buffer or slow copy operation":
    "Se han perdido %d entradas por un búfer pequeño o una copia lenta",
"Same instruction multiple times (different registers)":
    "La misma instrucción varias veces (con distintos registros)",

# --- codigo y opcodes ---
"Code:": "Código:",
"Code Address": "Dirección de código",
"Code Filter": "Filtro de código",
"Code list/Pause": "Lista de código / Pausa",
"Filtering addresses": "Filtrando direcciones",
"Has been executed": "Se ha ejecutado",
"Has not been executed": "No se ha ejecutado",
"Executed": "Ejecutado",
"Addresses executed since last filter operation:":
    "Direcciones ejecutadas desde el último filtrado:",
"Load a previous trace and filters out the CALL's from there":
    "Carga una traza anterior y filtra las llamadas a partir de ella",
"Load all instructions into the list or just the CALL's ?":
    "¿Cargar todas las instrucciones en la lista o solo las llamadas?",
"Call's only": "Solo llamadas",
"Launch branch mapper": "Abrir el mapeador de ramas",
"Start Mapping": "Iniciar el mapeo",
"The following codes execute %s": "Los siguientes códigos ejecutan %s",
"The following addresses have been accessed by the code you selected":
    "El código seleccionado ha accedido a las siguientes direcciones",
"The following %d addresses have been accessed by the code you selected":
    "El código seleccionado ha accedido a estas %d direcciones",
"This address has been accessed by the code you selected":
    "El código seleccionado ha accedido a esta dirección",
"Accessed addresses by %x": "Direcciones a las que accede %x",
"View Disassembly": "Ver el desensamblado",
"Disassemble Memory Region": "Desensamblar la región de memoria",
"Browse Memory Region": "Explorar la región de memoria",
"Single-line assembler": "Ensamblador de una línea",
"Input the assembly code to find. Wildcards( * ) supported.":
    "Introduce el código ensamblador que buscar. Admite comodines ( * ).",
"Opcodes only (no address)": "Solo opcodes (sin dirección)",
"Bytes+Opcodes+Comments": "Bytes + opcodes + comentarios",
"Show section addresses": "Mostrar las direcciones de sección",
"Go to Offset": "Ir al desplazamiento",
"Fill in the Offset you want to go to": "Indica el desplazamiento al que quieres ir",
"Add Offset Above": "Añadir un desplazamiento encima",
"Add Offset Below": "Añadir un desplazamiento debajo",
"Click: Add New Offset. Ctrl+Click: Add New Offset to the opposite location":
    "Clic: añade un desplazamiento. Ctrl+clic: lo añade en el lado opuesto",
"Click: Remove Offset. Ctrl+Click: Remove Offset from the opposite location":
    "Clic: quita un desplazamiento. Ctrl+clic: lo quita del lado opuesto",
"Entry Point": "Punto de entrada",
"Find Previous": "Buscar anterior",
"Syntax Check": "Comprobar la sintaxis",
"Enter the text to search:": "Introduce el texto que buscar:",
"Search pattern:": "Patrón de búsqueda:",

# --- registros y memoria ---
"Register": "Registro",
"Register panel": "Panel de registros",
"Change registerview font": "Cambiar la fuente del panel de registros",
"Copy all registers values to clipboard": "Copiar todos los registros al portapapeles",
"Copy selected register value to clipboard": "Copiar el registro seleccionado al portapapeles",
"Compare FPU/XMM": "Comparar FPU/XMM",
"Change extended state (FPU/XMM)": "Cambiar el estado extendido (FPU/XMM)",
"Physical Address:": "Dirección física:",
"Virtual Address: ": "Dirección virtual: ",
"Access Type": "Tipo de acceso",
"Execute Access": "Acceso de ejecución",
"Read/Write Access": "Acceso de lectura y escritura",
"Write Access ": "Acceso de escritura ",
"Read Execute": "Lectura y ejecución",
"Read Write": "Lectura y escritura",
"Read Write Execute": "Lectura, escritura y ejecución",
"Lock page": "Bloquear la página",
"Make possible": "Hacer posible",
"Write Combine": "Combinación de escritura",
"Don't scan memory that is protected with the Write Combine option":
    "No escanear la memoria protegida con la opción Write Combine",
"Megabyte": "Megabyte",
"Only when the size is bigger than:": "Solo cuando el tamaño sea mayor que:",
"Pagebase Switcher (CR3)": "Conmutador de base de página (CR3)",
"CR3 Switcher": "Conmutador de CR3",
"Select or type the new page base address (CR3) for this memory view window":
    "Selecciona o escribe la nueva dirección base de página (CR3) para esta ventana",
"Record CR3 list": "Registrar la lista de CR3",
"Failure getting the Memory Management registry key":
    "No se pudo obtener la clave de registro de administración de memoria",
"Failure to open the registry entry": "No se pudo abrir la entrada del registro",
"Hold CTRL to select multiple modules": "Mantén CTRL para seleccionar varios módulos",
"Always force load modules": "Forzar siempre la carga de módulos",

# --- DBVM ---
"DBVM Breakpoint": "Punto de interrupción DBVM",
"DBVM Breakpoint (+1 instruction)": "Punto de interrupción DBVM (+1 instrucción)",
"DBVM-Level Breakpoint": "Punto de interrupción a nivel de DBVM",
"DBVM CR3 Log": "Registro de CR3 de DBVM",
"DBVM Watch Config": "Configuración de vigilancia de DBVM",
"DBVM Find....": "Buscar con DBVM...",
"DBVM Activate Cloak": "Activar el ocultamiento de DBVM",
"DBVM Disable Cloak": "Desactivar el ocultamiento de DBVM",
"DBVM Native Break and Trace": "Interrupción y traza nativas de DBVM",
"DBVM Find out what writes or accesses this address":
    "Averiguar con DBVM qué escribe o accede a esta dirección",
"DBVM Find out what addresses this instruction accesses":
    "Averiguar con DBVM a qué direcciones accede esta instrucción",
"Use DBVM-level debugger": "Usar el depurador a nivel de DBVM",
"Use DBVM Cloaked BP's": "Usar puntos de interrupción ocultos de DBVM",
"Let DBVM do the break and trace internally":
    "Dejar que DBVM haga la interrupción y la traza internamente",
"Your system does not support DBVM. Perhaps it is already inside a VM":
    "Tu sistema no admite DBVM. Puede que ya esté dentro de una máquina virtual",
"Your system is running DBVM version %s (%.0n bytes free (%d pages))":
    "Tu sistema ejecuta DBVM versión %s (%.0n bytes libres (%d páginas))",
"Sorry, but you need DBVM for DBVM level debugging":
    "Necesitas DBVM para depurar a nivel de DBVM",
"DBVM level debug does not work on the 32-bit CE":
    "La depuración a nivel de DBVM no funciona en la versión de 32 bits",
"Debugger interface %s does not support DBVM breakpoints":
    "La interfaz de depuración %s no admite puntos de interrupción de DBVM",
"Failure setting a DBVM ChangeRegOnBP breakpoint":
    "No se pudo establecer un punto de interrupción ChangeRegOnBP de DBVM",
"You can't use kerneldebug in 64-bit without DBVM":
    "No puedes usar la depuración de kernel en 64 bits sin DBVM",
"Trigger copy-on-write": "Forzar copia al escribir",
"Trigger copy-on-write before activating watches":
    "Forzar copia al escribir antes de activar las vigilancias",
"Automatically add allocated memory by CE as watched regions":
    "Vigilar automáticamente la memoria que reserve Cheat Engine",

# --- errores y avisos ---
"No error": "Sin errores",
"Everything ok": "Todo correcto",
"not supported in this version": "no se admite en esta versión",
" is not yet supported": " todavía no se admite",
"something happened": "ha ocurrido algo",
"Doing something": "Trabajando",
"<Error message here>": "<mensaje de error aquí>",
"Error in script %s : %s": "Error en el script %s: %s",
"Error in script : %s": "Error en el script: %s",
"Lua error in a secondary thread": "Error de Lua en un hilo secundario",
"Generate errorlogs": "Generar registros de errores",
"The value provided can not be encoded in a 32-bit field":
    "El valor indicado no cabe en un campo de 32 bits",
"Failure allocating memory near %.8x for variable named %s in script %s":
    "No se pudo reservar memoria cerca de %.8x para la variable %s del script %s",
"The {$TRY} at line %d has no matching {$EXCEPT}":
    "El {$TRY} de la línea %d no tiene su {$EXCEPT}",
"The address in createthreadandwait(%s) is not valid":
    "La dirección de createthreadandwait(%s) no es válida",
"Failure to configure the ultimap driver":
    "No se pudo configurar el controlador de ultimap",
"Timeout while trying to set DEP policy. Continue with the breakpoint?":
    "Se agotó el tiempo al aplicar la política DEP. ¿Continuar con el punto de interrupción?",
"Failed enabling No Execute": "No se pudo activar No Execute",
"Failed enabling No Execute AND blocked it from every changing. Fuck":
    "No se pudo activar No Execute y además quedó bloqueado sin poder cambiarse",
"Execute page exception breakpoints are not possible on your system":
    "Tu sistema no admite puntos de interrupción por excepción de ejecución de página",
"Ooops, looks like the process does not support No Execute":
    "Parece que el proceso no admite No Execute",
"Invalid ceserver version. ( %s )": "Versión de ceserver no válida ( %s )",
"The VEH dll seems to have failed to load": "Parece que la DLL de VEH no se pudo cargar",
"Copying %s.dat to %s failed. Please make sure the file still exists":
    "No se pudo copiar %s.dat a %s. Comprueba que el archivo siga existiendo",
"You'll need a newer CE version to open this file":
    "Necesitas una versión más nueva de Cheat Engine para abrir este archivo",
"The version of %s is incompatible with this Cheat Engine version":
    "La versión de %s no es compatible con esta versión de Cheat Engine",
"This is not a Trainer made by Cheat Engine (If it is a Trainer at all!)":
    "Esto no es un trainer creado con Cheat Engine (si es que es un trainer)",
"The lua script in this trainer has some issues and will therefore not load":
    "El script Lua de este trainer tiene problemas, así que no se cargará",
"Error executing this table's lua script named %s: %s":
    "Error al ejecutar el script Lua «%s» de esta tabla: %s",
"Extended debug info is being loaded (%d %%)":
    "Cargando información de depuración extendida (%d %%)",

# --- ajustes ---
"Font quality": "Calidad de la fuente",
"The font quality can impact speed": "La calidad de la fuente puede afectar al rendimiento",
"override font size": "forzar el tamaño de fuente",
"Change Font": "Cambiar la fuente",
"Foreground Color": "Color de primer plano",
"Set color": "Definir el color",
"Style": "Estilo",
"Bold": "Negrita",
"Italic": "Cursiva",
"Strikeout": "Tachado",
"Underline": "Subrayado",
"Autocomplete": "Autocompletar",
"Format:": "Formato:",
"Cursor": "Cursor",
"Editing": "Edición",
"Seperator line": "Línea separadora",
"Top line": "Línea superior",
"Highlight Access": "Resaltar los accesos",
"Highlight Change": "Resaltar los cambios",
"Highlighter configurator": "Configuración del resaltado",
"C highlighting preferences": "Preferencias de resaltado de C",
"Lua syntax highlighting preferences": "Preferencias de resaltado de Lua",
"Auto assembler syntax highlighting preferences":
    "Preferencias de resaltado del ensamblador automático",
"Classic view": "Vista clásica",
"Original rendering system (Slow on mac)": "Sistema de renderizado original (lento en Mac)",
"Picture Format": "Formato de imagen",
"BMP (Fast, but requires a gigantic harddisk) ":
    "BMP (rápido, pero ocupa muchísimo disco) ",
"PNG (Slow, small files)": "PNG (lento, archivos pequeños)",
"Disable Dark Mode support (Requires a restart)":
    "Desactivar el modo oscuro (requiere reiniciar)",
"Collect all garbage every few seconds":
    "Recoger toda la basura cada pocos segundos",
"Passive garbage collection": "Recolección de basura pasiva",
"Separate Lua state": "Estado de Lua independiente",
"Only when signed, else ask": "Solo si está firmado; si no, preguntar",
"Only automatically execute lua scripts from trusted sources, else ask":
    "Ejecutar automáticamente solo los scripts Lua de origen fiable; si no, preguntar",
"Sort on click": "Ordenar al hacer clic",
"Filter by name": "Filtrar por nombre",
"Sort by name": "Ordenar por nombre",
"Direction": "Dirección",
"Down": "Abajo",
"Up": "Arriba",
"Move left": "Mover a la izquierda",
"Move right": "Mover a la derecha",
"Redo": "Rehacer",
"Ignore": "Ignorar",
"Repeat": "Repetir",
"Current": "Actual",
"Status": "Estado",
"Author": "Autor",
"Date": "Fecha",
"Game": "Juego",
"Version": "Versión",
"Applications": "Aplicaciones",
"Processes": "Procesos",
"Windows": "Ventanas",
"Architecture": "Arquitectura",
"Target is 32-bit": "El objetivo es de 32 bits",
"Target is 64-bit": "El objetivo es de 64 bits",
"C-Code": "Código C",
"C-#includes": "#includes de C",
"C Compiler by Tiny C-Compiler": "Compilador de C basado en Tiny C Compiler",
"Clear Selection": "Borrar la selección",
"Cancels the current operation": "Cancela la operación actual",
"Cancel List Refresh": "Cancelar la actualización de la lista",
"Extended (default)": "Extendido (predeterminado)",
"Rename tab": "Renombrar la pestaña",
"What should the new name be?": "¿Cuál será el nuevo nombre?",
"Open in new window": "Abrir en una ventana nueva",
"Open an address file": "Abrir un archivo de direcciones",
"Save an address file": "Guardar un archivo de direcciones",
"Load Recent": "Abrir reciente",
"Lua documentation": "Documentación de Lua",
"Get object list": "Obtener la lista de objetos",
"Add unlisted object": "Añadir un objeto no listado",
"CLR Runtime table": "Tabla del entorno de ejecución CLR",
"Saving pointermap": "Guardando el mapa de punteros",
"Do you want resultid column filled? It will take up additional disk space.":
    "¿Quieres rellenar la columna resultid? Ocupará más espacio en disco.",
"Do you wish to use offsets sum for sorting?":
    "¿Quieres ordenar por la suma de los desplazamientos?",
"Do you wish to sort pointerlist by level, then module, then offsets?":
    "¿Quieres ordenar la lista de punteros por nivel, luego módulo y luego desplazamientos?",
"Deactivate on release": "Desactivar al soltar",
"Restore to original on release": "Restaurar el original al soltar",
"Only while hotkey is down/Restore when released":
    "Solo mientras se mantenga el atajo; restaurar al soltarlo",
"Popup/Hide Cheat Engine": "Mostrar u ocultar Cheat Engine",
"(Won't have any effect until you (re)open a process)":
    "(No tendrá efecto hasta que abras o reabras un proceso)",
"Symbol:": "Símbolo:",
"Symbol groups:": "Grupos de símbolos:",
"Unregister": "Anular el registro",
"Unregister all": "Anular todos los registros",
"Cancel this symbol lookup": "Cancelar esta búsqueda de símbolos",
"Symbol lookup taking long": "La búsqueda de símbolos está tardando",
"And skip all symbols until loaded": "Y omitir todos los símbolos hasta que carguen",
"And skip this symbol until loaded": "Y omitir este símbolo hasta que cargue",
"This window will autoclose once the symbol has been found":
    "Esta ventana se cerrará sola cuando se encuentre el símbolo",
"Cheat Engine signature files": "Archivos de firma de Cheat Engine",
"Failed to load Cheat Engine public key":
    "No se pudo cargar la clave pública de Cheat Engine",
"Select your Cheat Engine signature file":
    "Selecciona tu archivo de firma de Cheat Engine",
"Cheat Engine Tutorial Games": "Juegos del tutorial de Cheat Engine",
"Cheat-E-coins left in your inventory:": "Cheat-E-coins que te quedan:",
"place your code here": "escribe aquí tu código",
"This script does blah blah blah": "Este script hace tal y tal",
"this is allocated memory, you have read,write,execute access":
    "esto es memoria reservada: tienes acceso de lectura, escritura y ejecución",
"code from here till the end of the code will be used to disable the cheat":
    "el código desde aquí hasta el final se usará para desactivar el truco",
"code from here to '[DISABLE]' will be used to enable the cheat":
    "el código desde aquí hasta '[DISABLE]' se usará para activar el truco",
"14 byte JMP": "JMP de 14 bytes",
"5 byte JMP": "JMP de 5 bytes",
"example": "ejemplo",
"Value:Description or (memrecdescription)": "Valor:Descripción o (memrecdescription)",
"*:Text Value to display if no value in the list is found":
    "*:Texto que mostrar si no se encuentra ningún valor de la lista",
})


# ultimas cadenas traducibles; el resto que queda son nombres de componentes,
# teclas, terminos tecnicos y plantillas hex, que deben quedarse como estan
T.update({
"Unlock (%.8x-%.8x)": "Desbloquear (%.8x-%.8x)",
"Reserved word 2": "Palabra reservada 2",
"Reserved word 3": "Palabra reservada 3",
"Reserved word 4": "Palabra reservada 4",
". Have you disabled 'System Integrity Protection'(SIP) yet?":
    ". ¿Has desactivado ya la protección de integridad del sistema (SIP)?",
"...<max reached>...": "...<máximo alcanzado>...",
"BUY 10 for $0.99": "COMPRAR 10 por 0,99 $",
"BUY 100 for $8.99": "COMPRAR 100 por 8,99 $",
"BUY 1000 for $79.99": "COMPRAR 1000 por 79,99 $",
"Cheat Engine Tutorial (x86_64)": "Tutorial de Cheat Engine (x86_64)",
"Cheat Engine Tutorial (AArch64)": "Tutorial de Cheat Engine (AArch64)",
})

# --- capa 4: cadenas que la plantilla de de_DE no trae -----------------------
# de_DE viene de una version anterior de CE, asi que le faltan cadenas que si
# estan en los .lfm actuales. Se anexan al final del .po.
EXTRA = [
    ("tmainform.cbpresentmemoryonly.caption",
     "Active memory only", "Solo memoria activa"),
    ("tmainform.mitriggeraccessviolation.caption",
     "Test access violation", "Probar una violación de acceso"),
    ("tmainform.mitestaccessviolationthread.caption",
     "Test access violation in thread", "Probar una violación de acceso en un hilo"),
]

# --- capa 2: tildes ----------------------------------------------------------
# Solo formas que la llevan de verdad. Ojo con los plurales: "Direcciones" y
# "Opciones" son llanas terminadas en -s y NO la llevan.
ACENTOS = {
    "Direccion": "Dirección", "Descripcion": "Descripción",
    "Alineacion": "Alineación", "Ultimos": "Últimos", "Ultima": "Última",
    "Ultimo": "Último", "Digitos": "Dígitos", "Codigo": "Código",
    "Busqueda": "Búsqueda", "Numero": "Número", "Version": "Versión",
    "Opcion": "Opción", "Configuracion": "Configuración",
    "Automatico": "Automático", "Rapido": "Rápido", "Modulo": "Módulo",
    "Titulo": "Título", "Maximo": "Máximo", "Minimo": "Mínimo",
    "Parametro": "Parámetro", "Metodo": "Método", "Seleccion": "Selección",
    "Funcion": "Función", "Ejecucion": "Ejecución", "Sesion": "Sesión",
    "Aplicacion": "Aplicación", "Informacion": "Información",
    "Depuracion": "Depuración", "Instruccion": "Instrucción",
    "Excepcion": "Excepción", "Region": "Región", "Tamano": "Tamaño",
    "Pagina": "Página", "Unico": "Único", "Multiple": "Múltiple",
    "Automaticamente": "Automáticamente", "Aqui": "Aquí",
    "Despues": "Después", "Accion": "Acción", "Anadir": "Añadir",
    "Ingles": "Inglés", "Espanol": "Español",
}

_ac = re.compile(r'\b(' + '|'.join(sorted(ACENTOS, key=len, reverse=True)) + r')\b',
                 re.IGNORECASE)


def poner_acentos(s):
    def rep(m):
        w = m.group(1)
        base = ACENTOS.get(w[0].upper() + w[1:].lower())
        if not base:
            return w
        if w.isupper():
            return base.upper()
        if w[0].isupper():
            return base
        return base[0].lower() + base[1:]
    return _ac.sub(rep, s)


_ESC = {'n': '\n', 't': '\t', 'r': '\r', '"': '"', '\\': '\\'}


def unescape(s):
    """cl_CL trae escapes rotos ("c:\\Registro.dat" con una sola barra), asi que
    se normaliza a texto plano y se vuelve a escapar al escribir."""
    return re.sub(r'\\(.)', lambda m: _ESC.get(m.group(1), '\\' + m.group(1)), s)


def escape(s):
    s = s.replace('\\', '\\\\').replace('"', '\\"')
    return s.replace('\n', '\\n').replace('\t', '\\t').replace('\r', '\\r')


_LINE = re.compile(r'^\s*"((?:[^"\\]|\\.)*)"\s*$')


def read_field(lines, start, keyword):
    """Lee `keyword "..."` con sus lineas de continuacion.

    El formato .po parte las cadenas largas en varias lineas seguidas, que
    gettext concatena. Ignorarlas dejaba la traduccion pegada al resto del
    texto original: 348 entradas de la plantilla vienen asi.

    Devuelve (texto plano, indice de la primera linea que ya no pertenece).
    """
    m = re.match(r'^%s\s+"((?:[^"\\]|\\.)*)"\s*$' % keyword, lines[start])
    if not m:
        return None, start + 1

    parts = [m.group(1)]
    i = start + 1
    while i < len(lines):
        cont = _LINE.match(lines[i])
        if not cont:
            break
        parts.append(cont.group(1))
        i += 1

    return unescape(''.join(parts)), i


def field_of(block, keyword):
    lines = block.split('\n')
    for i, l in enumerate(lines):
        if l.startswith(keyword):
            return read_field(lines, i, keyword)[0]
    return None


def set_msgstr(block, texto):
    """Sustituye msgstr y descarta sus continuaciones."""
    lines = block.split('\n')
    out = []
    i = 0
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


def parse_po(path):
    """msgid -> msgstr en texto plano, ignorando entradas vacias."""
    txt = io.open(path, encoding='utf-8', errors='replace').read()
    out = {}
    for b in txt.split('\n\n'):
        k = field_of(b, 'msgid')
        v = field_of(b, 'msgstr')
        if k and v:
            out[k] = v
    return out


def main():
    if len(sys.argv) != 4:
        print(__doc__)
        sys.exit(1)
    plantilla, base_po, dst = sys.argv[1:4]

    base = {k: poner_acentos(v) for k, v in parse_po(base_po).items()}

    txt = io.open(plantilla, encoding='utf-8', errors='replace').read()
    out, n_t, n_b = [], 0, 0

    for b in txt.split('\n\n'):
        if not b.strip():
            continue
        key = field_of(b, 'msgid')
        #'' is the header block (Content-Type, charset...), which must survive
        if not key:
            out.append(b)
            continue

        if key in T:
            tr, n_t = T[key], n_t + 1
        elif key in base:
            tr, n_b = base[key], n_b + 1
        else:
            tr = ''

        out.append(set_msgstr(b, tr))

    ya = {field_of(b, 'msgid') for b in out}
    n_e = 0
    for ref, mid, mstr in EXTRA:
        if mid in ya:
            continue
        out.append('#: %s\nmsgid "%s"\nmsgstr "%s"' % (ref, escape(mid), escape(mstr)))
        n_e += 1

    io.open(dst, 'w', encoding='utf-8', newline='\n').write('\n\n'.join(out) + '\n')
    print("revisadas a mano : %d" % n_t)
    print("desde cl_CL      : %d" % n_b)
    print("anexadas         : %d" % n_e)
    print("total traducidas : %d" % (n_t + n_b + n_e))


if __name__ == '__main__':
    main()
