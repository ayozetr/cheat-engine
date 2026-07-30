#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Traduce las cadenas visibles de la ventana principal a it, pt y fr.

    python3 fill-visible.py [--apply]

No pretende completar el idioma entero: cubre lo que se ve al abrir Cheat
Engine (botones de escaneo, cabeceras, menus y los avisos mas frecuentes),
que es donde se nota la diferencia. Lo que queda vacio sigue saliendo en
ingles, que es el comportamiento normal de gettext.

Solo se rellenan entradas vacias: nunca pisa una traduccion existente.
"""
import re, io, os, sys

# ingles -> (it, pt_BR, fr)
T = {
"First Scan": ("Prima scansione", "Primeira varredura", "Premier scan"),
"New Scan": ("Nuova scansione", "Nova varredura", "Nouveau scan"),
"Next Scan": ("Scansione successiva", "Próxima varredura", "Scan suivant"),
"Undo Scan": ("Annulla scansione", "Desfazer varredura", "Annuler le scan"),
"Scan": ("Scansiona", "Varrer", "Scanner"),
"Memory View": ("Vista memoria", "Ver memória", "Vue mémoire"),
"Add Address Manually": ("Aggiungi indirizzo", "Adicionar endereço", "Ajouter une adresse"),
"No Process Selected": ("Nessun processo selezionato", "Nenhum processo selecionado", "Aucun processus sélectionné"),
"Value": ("Valore", "Valor", "Valeur"),
"Value:": ("Valore:", "Valor:", "Valeur :"),
"Text:": ("Testo:", "Texto:", "Texte :"),
"Scan Type": ("Tipo scansione", "Tipo de varredura", "Type de scan"),
"Value Type": ("Tipo di valore", "Tipo de valor", "Type de valeur"),
"Exact Value": ("Valore esatto", "Valor exato", "Valeur exacte"),
"Bigger than...": ("Maggiore di...", "Maior que...", "Supérieur à..."),
"Smaller than...": ("Minore di...", "Menor que...", "Inférieur à..."),
"Value between...": ("Valore compreso tra...", "Valor entre...", "Valeur entre..."),
"Unknown initial value": ("Valore iniziale sconosciuto", "Valor inicial desconhecido", "Valeur initiale inconnue"),
"Increased value": ("Valore aumentato", "Valor aumentado", "Valeur augmentée"),
"Decreased value": ("Valore diminuito", "Valor diminuído", "Valeur diminuée"),
"Changed value": ("Valore cambiato", "Valor alterado", "Valeur modifiée"),
"Unchanged value": ("Valore invariato", "Valor inalterado", "Valeur inchangée"),
"Memory Scan Options": ("Opzioni di scansione", "Opções de varredura", "Options de scan"),
"Start": ("Inizio", "Início", "Début"),
"Stop": ("Fine", "Fim", "Fin"),
"Writable": ("Scrivibile", "Gravável", "Accessible en écriture"),
"Executable": ("Eseguibile", "Executável", "Exécutable"),
"CopyOnWrite": ("Copia su scrittura", "Cópia ao gravar", "Copie à l'écriture"),
"Fast Scan": ("Scansione rapida", "Varredura rápida", "Scan rapide"),
"Alignment": ("Allineamento", "Alinhamento", "Alignement"),
"Last Digits": ("Ultime cifre", "Últimos dígitos", "Derniers chiffres"),
"Pause the game while scanning": ("Metti in pausa il gioco durante la scansione",
    "Pausar o jogo durante a varredura", "Mettre le jeu en pause pendant le scan"),
"Enable Speedhack": ("Attiva speedhack", "Ativar speedhack", "Activer le speedhack"),
"Unrandomizer": ("Anti-casualità", "Anti-aleatoriedade", "Anti-aléatoire"),
"Lua formula": ("Formula Lua", "Fórmula Lua", "Formule Lua"),
"Not": ("No", "Não", "Non"),
"Hexadecimal": ("Esadecimale", "Hexadecimal", "Hexadécimal"),
"Decimal": ("Decimale", "Decimal", "Décimal"),
"All": ("Tutto", "Tudo", "Tout"),
"Found:": ("Trovati:", "Encontrados:", "Trouvés :"),
"Physical Memory": ("Memoria fisica", "Memória física", "Mémoire physique"),
"Safer memory access": ("Accesso alla memoria più sicuro", "Acesso à memória mais seguro",
    "Accès mémoire plus sûr"),
"Terminating scan...": ("Interruzione della scansione...", "Cancelando a varredura...",
    "Arrêt du scan..."),
"Scanresult": ("Risultato della scansione", "Resultado da varredura", "Résultat du scan"),
"Save scan results": ("Salva i risultati", "Salvar os resultados", "Enregistrer les résultats"),
"Saved scan results": ("Risultati salvati", "Resultados salvos", "Résultats enregistrés"),
"Compare to first/saved scan": ("Confronta con la prima scansione o con una salvata",
    "Comparar com a primeira varredura ou uma salva", "Comparer au premier scan ou à un scan enregistré"),
"Previous": ("Precedente", "Anterior", "Précédent"),
"Previous value list": ("Elenco dei valori precedenti", "Lista de valores anteriores",
    "Liste des valeurs précédentes"),
"First": ("Primo", "Primeiro", "Premier"),
"Modified": ("Modificato", "Modificado", "Modifié"),
"Saved": ("Salvato", "Salvo", "Enregistré"),
"Save to disk": ("Salva su disco", "Salvar em disco", "Enregistrer sur le disque"),
"Current process": ("Processo corrente", "Processo atual", "Processus courant"),
"Groups": ("Gruppi", "Grupos", "Groupes"),
"Custom LUA type": ("Tipo LUA personalizzato", "Tipo LUA personalizado", "Type LUA personnalisé"),
"Custom Type Name": ("Nome del tipo personalizzato", "Nome do tipo personalizado",
    "Nom du type personnalisé"),
"Advanced Options": ("Opzioni avanzate", "Opções avançadas", "Options avancées"),
"Table Extras": ("Extra della tabella", "Extras da tabela", "Extras de la table"),

# lista de direcciones
"Active": ("Attivo", "Ativo", "Actif"),
"Description": ("Descrizione", "Descrição", "Description"),
"Address": ("Indirizzo", "Endereço", "Adresse"),
"Type": ("Tipo", "Tipo", "Type"),
"Change value": ("Cambia valore", "Alterar valor", "Modifier la valeur"),
"Change this value to:": ("Cambia questo valore in:", "Alterar este valor para:",
    "Remplacer cette valeur par :"),
"Change these values to:": ("Cambia questi valori in:", "Alterar estes valores para:",
    "Remplacer ces valeurs par :"),
"Change the description to:": ("Cambia la descrizione in:", "Alterar a descrição para:",
    "Remplacer la description par :"),
"Change script": ("Modifica lo script", "Alterar o script", "Modifier le script"),
"Delete this address": ("Elimina questo indirizzo", "Excluir este endereço",
    "Supprimer cette adresse"),
"Delete these addresses": ("Elimina questi indirizzi", "Excluir estes endereços",
    "Supprimer ces adresses"),
"Enable Cheat": ("Attiva il trucco", "Ativar o truque", "Activer le cheat"),
"Disable Cheat": ("Disattiva il trucco", "Desativar o truque", "Désactiver le cheat"),
"Copy selected addresses": ("Copia gli indirizzi selezionati", "Copiar os endereços selecionados",
    "Copier les adresses sélectionnées"),
"Search for this array": ("Cerca questa sequenza", "Procurar esta sequência",
    "Rechercher cette séquence"),
"Search for text": ("Cerca testo", "Procurar texto", "Rechercher du texte"),
"Set a hotkey": ("Assegna una scorciatoia", "Definir um atalho", "Définir un raccourci"),
"Set hotkeys": ("Assegna le scorciatoie", "Definir os atalhos", "Définir les raccourcis"),
"Always hide children": ("Nascondi sempre i figli", "Sempre ocultar os filhos",
    "Toujours masquer les enfants"),

# dialogos frecuentes
"Cancel": ("Annulla", "Cancelar", "Annuler"),
"Delete": ("Elimina", "Excluir", "Supprimer"),
"Rename": ("Rinomina", "Renomear", "Renommer"),
"Error": ("Errore", "Erro", "Erreur"),
"CE Error:": ("Errore di CE:", "Erro do CE:", "Erreur de CE :"),
"Unspecified error": ("Errore non specificato", "Erro não especificado", "Erreur non spécifiée"),
"Are you sure?": ("Sei sicuro?", "Tem certeza?", "Êtes-vous sûr ?"),
"Language": ("Lingua", "Idioma", "Langue"),
"Which language do you wish to use?": ("Quale lingua vuoi usare?", "Qual idioma você quer usar?",
    "Quelle langue souhaitez-vous utiliser ?"),
"Empty Recent Files List": ("Svuota l'elenco dei file recenti", "Limpar a lista de arquivos recentes",
    "Vider la liste des fichiers récents"),
"Give the new filename": ("Indica il nuovo nome del file", "Informe o novo nome do arquivo",
    "Indiquez le nouveau nom du fichier"),
"Force termination": ("Forza la chiusura", "Forçar o encerramento", "Forcer la fermeture"),
"Info about this table:": ("Informazioni su questa tabella:", "Informações sobre esta tabela:",
    "Informations sur cette table :"),
"Lua script: Cheat Table": ("Script Lua: tabella dei trucchi", "Script Lua: tabela de truques",
    "Script Lua : table de cheats"),
"This is not a valid notation": ("Questa notazione non è valida", "Esta notação não é válida",
    "Cette notation n'est pas valide"),
"This is not an valid value": ("Questo valore non è valido", "Este valor não é válido",
    "Cette valeur n'est pas valide"),
"Not the same size!": ("Dimensione diversa", "Tamanho diferente", "Taille différente"),
"failed to load": ("caricamento non riuscito", "falha ao carregar", "échec du chargement"),
"Scan error:%s": ("Errore di scansione: %s", "Erro de varredura: %s", "Erreur de scan : %s"),
"Comparing to %s": ("Confronto con %s", "Comparando com %s", "Comparaison avec %s"),
"Group %s": ("Gruppo %s", "Grupo %s", "Groupe %s"),
"Invalid stop address: %s": ("Indirizzo finale non valido: %s", "Endereço final inválido: %s",
    "Adresse de fin non valide : %s"),
"%s is not a valid speed": ("%s non è una velocità valida", "%s não é uma velocidade válida",
    "%s n'est pas une vitesse valide"),
"Restore and show": ("Ripristina e mostra", "Restaurar e mostrar", "Restaurer et afficher"),
"brings Cheat Engine to front": ("porta Cheat Engine in primo piano",
    "traz o Cheat Engine para a frente", "met Cheat Engine au premier plan"),
"will hide all windows": ("nasconde tutte le finestre", "oculta todas as janelas",
    "masque toutes les fenêtres"),
"Repeat": ("Ripeti", "Repetir", "Répéter"),
"Percent": ("Percentuale", "Porcentagem", "Pourcentage"),
"Case sensitive": ("Distingui maiuscole", "Diferenciar maiúsculas", "Sensible à la casse"),
"Codepage": ("Codifica", "Página de código", "Page de code"),
"Separate Lua state": ("Stato Lua separato", "Estado Lua separado", "État Lua séparé"),
"Codelist and pause": ("Elenco del codice e pausa", "Lista de código e pausa",
    "Liste du code et pause"),
"Generate groupscan command": ("Genera il comando di scansione per gruppi",
    "Gerar o comando de varredura por grupos", "Générer la commande de scan par groupes"),
"Unknown extension": ("Estensione sconosciuta", "Extensão desconhecida", "Extension inconnue"),
"<busy>": ("<occupato>", "<ocupado>", "<occupé>"),
"<Processing>": ("<Elaborazione>", "<Processando>", "<Traitement>"),
"<File in use>": ("<File in uso>", "<Arquivo em uso>", "<Fichier en cours d'utilisation>"),
"EXPIRED": ("SCADUTO", "EXPIRADO", "EXPIRÉ"),
}

LANGS = [('it_IT', 0), ('pt_BR', 1), ('fr_FR', 2)]

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


def main():
    apply = '--apply' in sys.argv
    here = os.path.dirname(os.path.abspath(__file__)) or '.'
    os.chdir(here)

    for lang, col in LANGS:
        src = os.path.join(lang, 'cheatengine-x86_64.po')
        if not os.path.exists(src):
            #it_IT no trae traduccion de interfaz: se parte de la plantilla
            base = 'de_DE/cheatengine-x86_64.po'
            txt = io.open(base, encoding='utf-8', errors='replace').read()
            blocks = [set_msgstr(b, '') if field(b, 'msgid') else b
                      for b in txt.split('\n\n') if b.strip()]
            nuevo = True
        else:
            txt = io.open(src, encoding='utf-8', errors='replace').read()
            blocks = [b for b in txt.split('\n\n') if b.strip()]
            nuevo = False

        out, n = [], 0
        for b in blocks:
            k = field(b, 'msgid')
            if not k:
                out.append(b)
                continue
            #solo se rellena lo vacio: nunca se pisa una traduccion existente
            if not field(b, 'msgstr') and k in T:
                out.append(set_msgstr(b, T[k][col]))
                n += 1
            else:
                out.append(b)

        print('%-8s %3d cadenas rellenadas%s' % (lang, n, '  (archivo nuevo)' if nuevo else ''))
        if apply:
            os.makedirs(lang, exist_ok=True)
            io.open(src, 'w', encoding='utf-8', newline='\n').write('\n\n'.join(out) + '\n')

    if not apply:
        print('\n(sin --apply no se ha escrito nada)')


if __name__ == '__main__':
    main()
