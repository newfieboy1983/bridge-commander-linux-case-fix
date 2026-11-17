# [Linux/Wine fix] Remastered + Orion: main menu crash (CreateCurve ZeroDivisionError / "Wave Defense" GetString) — caused by case-split folders

If you're running the GOG Bridge Commander + Remastered v1.2 + Orion under
Wine/Proton/Lutris and the game dies after the opening movie with either

- `UIHelpers.py line 126, in CreateCurve — ZeroDivisionError: float division`, or
- `AttributeError: 'None' object has no attribute 'GetString'` on the "Wave Defense" button,

and typing `resume` gets you a main menu with most components missing —
it's not your Wine prefix, your resolution, or the uptime bug. It's your
folder capitalization.

**Cause:** Windows treats `Data` and `data` as one folder; Linux doesn't.
The mod zips disagree on case, so you end up with the stock game in
lowercase `data/` + `sfx/` and the Orion overlay stranded in capital
`Data/` + `SFX/`. Files the game wants in `data/TGL/` are stuck in
`Data/TGL/` — and worse, the LCARS textures load via `Data/Icons/...`
paths, so they land in the near-empty capital folder, fail, and every UI
icon registers 0×0. `CreateCurve` divides by an icon width. Boom, in
every menu, at every resolution.

**Fix** (from inside the game folder, game closed):

```bash
rsync -a --backup --suffix=.pre-orion Data/ data/
rsync -a --backup --suffix=.pre-orion SFX/ sfx/
mkdir -p ../bc-case-fix-backup
mv Data ../bc-case-fix-backup/Data-capital
mv SFX  ../bc-case-fix-backup/SFX-capital
```

Merge the overlay into the lowercase tree (overwritten stock files keep
`.pre-orion` backups), then move the capital folders OUT — don't just
merge and leave them, or they keep shadowing the real tree. Nothing is
deleted; the parked folders are your pristine mod source.

Relaunch: full menu, curves, Wave Defense button, Orion themes and ships
all present. Full write-up with the debug-console diagnosis (you can
reproduce the -1 vs 0 texture-load test yourself) and an audit script
that finds case-twin folders automatically: https://github.com/newfieboy1983/bridge-commander-linux-case-fix
