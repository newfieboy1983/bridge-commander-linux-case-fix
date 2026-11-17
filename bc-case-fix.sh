#!/usr/bin/env bash
# bc-case-fix.sh - Bridge Commander on Linux: case-split folder fix
#
# THE PROBLEM
#   Bridge Commander mods (Remastered, Orion, most ship packs) are zips made
#   on Windows, where "Data" and "data" are the same folder. Extracted on
#   Linux they become TWO folders. Files strand in the capital tree, and
#   worse, the capital folder SHADOWS the real one: the game loads its
#   LCARS textures via "Data/Icons/..." paths, the lookup lands in the
#   near-empty capital Data/, every texture load fails, every UI icon
#   registers 0x0, and UIHelpers.CreateCurve divides by zero.
#
# SYMPTOMS THIS FIXES
#   * AttributeError: 'None' object has no attribute 'GetString'
#     (mainmenu.py, "Wave Defense" button - Options2.tgl stranded)
#   * ZeroDivisionError: float division
#     (UIHelpers.py line 126, CreateCurve - called from the main menu
#      and the multiplayer status window)
#   * Typing 'resume' in the debug console gets a main menu with most
#     of its components missing.
#
# WHAT IT DOES
#   1. Audits the install for directory case-twins (Data/data, SFX/sfx,
#      Scripts/scripts, and any others).
#   2. Merges each capital overlay folder into its lowercase twin with
#      rsync; overwritten files keep a .pre-orion backup beside them.
#   3. MOVES the capital folders out of the game directory (never
#      deletes) to a backup folder next to the install, so they can no
#      longer shadow the lowercase tree.
#
# USAGE
#   ./bc-case-fix.sh [--dry-run] [path-to-game-folder]
#   With no path, the default GOG location is tried.
#
# Quit the game before running. Tested on the GOG release under
# Lutris/Wine on Linux; the same layout applies to Proton installs.

set -eu

DRY_RUN=0
GAME=""

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        *) GAME="$arg" ;;
    esac
done

if [ -z "$GAME" ]; then
    GAME="$HOME/Games/gog/star-trek-bridge-commander/Star Trek Bridge Commander"
fi

if pgrep -f "stbc.exe" >/dev/null 2>&1; then
    echo "STOP: stbc.exe is running. Quit the game first, then re-run."
    exit 1
fi

[ -d "$GAME" ] || { echo "FAIL: game folder not found: $GAME"; echo "Pass the path explicitly: ./bc-case-fix.sh /path/to/Star Trek Bridge Commander"; exit 1; }
cd "$GAME"

find . -maxdepth 2 -iname "stbc.exe" | grep -q . || { echo "FAIL: no stbc.exe under $GAME - is this the game folder?"; exit 1; }

BACKUP="$(dirname "$GAME")/bc-case-fix-backup"

echo "Game folder: $GAME"
echo
echo "== Audit: directory case-twins in this install =="
find . -type d | tr 'A-Z' 'a-z' | sort | uniq -d | sed 's/^/   twin: /' || true
echo

for cap in Data SFX Scripts; do
    low="$(printf '%s' "$cap" | tr 'A-Z' 'a-z')"
    if [ -d "$cap" ] && [ -d "$low" ]; then
        echo "== $cap/ shadows $low/ =="
        if [ "$DRY_RUN" -eq 1 ]; then
            echo "   [dry-run] would rsync-merge $cap/ into $low/ (backups: *.pre-orion)"
            echo "   [dry-run] would move $cap/ to $BACKUP/$cap-capital"
        else
            mkdir -p "$BACKUP"
            rsync -a --backup --suffix=.pre-orion "$cap/" "$low/"
            mv "$cap" "$BACKUP/$cap-capital"
            echo "   merged into $low/ ; capital folder parked at $BACKUP/$cap-capital"
        fi
    elif [ -d "$cap" ]; then
        echo "== $cap/ exists with no lowercase twin - leaving it alone =="
    else
        echo "== no capital $cap/ folder - OK =="
    fi
done

echo
echo "== Verify =="
if [ -d Data ] || [ -d SFX ] || [ -d Scripts ]; then
    echo "WARNING: a capital folder is still present in the game directory."
else
    echo "OK: no capital Data/SFX/Scripts folders in the game directory."
fi
[ -f data/Icons/STMenu.tga ] && echo "OK: data/Icons/STMenu.tga reachable in the merged tree."
[ -f data/TGL/Options2.tgl ] && echo "OK: data/TGL/Options2.tgl reachable (Orion installed)."

echo
echo "Done. Relaunch the game and let the opening movie finish:"
echo "the main menu should build completely, LCARS curves and all,"
echo "including the Wave Defense button. Nothing was deleted - the"
echo "capital folders are parked in $BACKUP and every overwritten"
echo "stock file kept a .pre-orion backup."
