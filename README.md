# Bridge Commander on Linux — the case-split folder fix

**For:** Star Trek: Bridge Commander (GOG release) + Remastered v1.2 + Orion,
running under Wine/Proton/Lutris on Linux.
**Fixes:** a main menu that crashes while building, or builds with most of
its components missing.

---

## Symptoms

After installing Remastered and Orion over the GOG game, launching on Linux
reaches the end of the opening movie and dies in the TG Python Exception
Debug Console with two errors:

```
File ".\Scripts\MainMenu\mainmenu.py", line 2021, in BuildMainMenuTopButtonPane
    pCreditsButton = App.STRoundedButton_CreateW(pDatabase2.GetString("Wave Defense"), ...)
AttributeError: 'None' object has no attribute 'GetString'

File "c:\utopia\current\build\scripts\UIHelpers.py", line 126, in CreateCurve
ZeroDivisionError: float division
```

The second error also fires from the multiplayer menus
(`MultiplayerMenus.py`, `BuildStatusWindow`). Typing `resume` in the debug
console gets you into a main menu that is missing most of its components —
the panes and buttons that build after the first curve never appear.

Resolution changes, fullscreen/windowed, and the Windows uptime bug are
**not** involved; all three were tested and eliminated.

## Root cause

Windows has a case-insensitive filesystem; Linux does not. The mod zips
don't agree on folder capitalization, so on Linux the install ends up with
**two trees**:

- `data/`, `sfx/` — the stock game (what the GOG installer created)
- `Data/`, `SFX/` — the Orion overlay, stranded in parallel

That split breaks the game twice, in two different ways:

1. **Stranded files.** `mainmenu.py` loads its string database from
   `data/TGL/Options2.tgl` — but that file is sitting in `Data/TGL/`.
   The load returns `None`, and the first lookup (`"Wave Defense"`, an
   Orion feature) crashes.

2. **Shadowing (the subtle one).** The LCARS UI loads every texture via
   capital paths — `Data/Icons/STMenu.tga`, `Data/Icons/Bridge/...`, etc.
   With a real capital `Data/` folder present, those lookups land in it —
   and it only contains the handful of files the overlay shipped. The
   loads fail, every LCARS icon registers as 0×0, and
   `UIHelpers.CreateCurve` divides by an icon width. This is why the
   crash happens at *every* resolution and in *every* menu: it's not a
   bad icon set, it's an empty one.

Verified live in the game's own debug console (a Python prompt — press
keys at `>>>`):

```
>>> print App.GraphicsModeInfo_GetCurrentMode().GetLcarsString()
LCARS_1600                                   <- engine mode is fine
>>> g = App.g_kIconManager.CreateIconGroup("TESTGRP")
>>> print g.LoadIconTexture("Data/Icons/STMenu.tga")
-1                                           <- capital path FAILS
>>> print g.LoadIconTexture("data/Icons/STMenu.tga")
0                                            <- lowercase path loads
```

## The fix

Merge each capital overlay folder into its lowercase twin, then move the
capital folders **out** of the game directory so they can't shadow
anything. Nothing is deleted: overwritten stock files keep a `.pre-orion`
backup, and the capital folders are parked next to the install as the
pristine mod source.

By hand, from inside the game folder:

```bash
rsync -a --backup --suffix=.pre-orion Data/ data/
rsync -a --backup --suffix=.pre-orion SFX/ sfx/
mkdir -p ../bc-case-fix-backup
mv Data ../bc-case-fix-backup/Data-capital
mv SFX  ../bc-case-fix-backup/SFX-capital
```

Or run the script in this repo, which audits the whole install for
case-twin directories, does the merges, parks the folders, and verifies
the result (`--dry-run` shows the plan without touching anything):

```bash
./bc-case-fix.sh [--dry-run] "/path/to/Star Trek Bridge Commander"
```

Quit the game before running it.

## Verifying

Relaunch and let the opening movie finish. The main menu should build
completely — LCARS curves, all six top buttons including **Wave Defense**,
and the Orion LCARS themes (Picard, Lower Decks, Gorn, Tholian…) in the
New Game pane. A Quick Battle ship list containing Orion-only ships
(Odyssey class, Orville) confirms the merged ship library.

## Notes

- The same trap applies to any Windows game modded on Linux: when a mod
  misbehaves after extraction, audit for case-twin directories **first**
  (`find . -type d | tr 'A-Z' 'a-z' | sort | uniq -d`).
- Stock GOG Bridge Commander on Linux is unaffected — a single tree has
  nothing to shadow it. The trap needs two trees, which is why it only
  shows up once capital-cased mod zips enter the picture.
- The 4GB Address Aware patch on `stbc.exe` is still recommended for
  large Quick Battles, per the Remastered readme — unrelated to this fix.

*Diagnosed and fixed on Nobara Linux (Wine via Lutris), November 2026,
with the game's own debug console as the probe. Shared so the next
captain doesn't have to re-derive it.*
