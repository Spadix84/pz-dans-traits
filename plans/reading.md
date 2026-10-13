# Reading

Design note, drafted 2026-10-12 from the user's idea and BUILT the same day
(deployed, unplayed). Where this note and the code differ, the code is right;
"As built" at the end lists what changed on the way. It covers
entertainment reading only: novels, comics, magazines, newspapers and other
print. Skill books and recipe magazines keep their vanilla behaviour.

## Why

In vanilla, reading for fun works like a vending machine. You find a title you
have not read, read it in a few minutes, and when you finish you get a fixed
drop in boredom, stress and unhappiness. After that the title gives nothing.
Who the character is doesn't matter, and neither does what they read, how
good it is or how long it is. Reading is just what you do when the stress
moodle shows up.

The user's goal: **turn reading into more than "decrease stress when
stressed".** Books get genres, a hidden quality and a real length. The relief
drips in while you read rather than all at once at the end. Each character
has a genre they like and a genre they dislike, and finds out which by
reading. Finishing a book gives a short mood moodle with a small buff matched
to its genre. A novel becomes something to carry on a run and read a chapter
of while you get your breath back.

A side effect the user wants: **Fast Reader becomes worth picking.** It
finishes more books, so it collects more finishing bonuses.

## Decisions taken (user, 2026-10-12)

1. **Full scope**: books, comics, magazines, newspapers and the rest of the
   entertainment print, with a 1993 America flavour. Shorter media get short
   reads and a small payoff.
2. **Tastes are found by reading.** They are hidden at the start. A book you
   especially loved gives a finishing bonus **0.25 higher** than normal.
3. **Lengths vary.**
   - Real books use their real page counts.
   - Vanilla titles vary by title, and so do picture books, so no two are the
     same length.
   - A Fast Reader who spends most of the day's free time reading can finish
     a novel in a day.
4. **Re-reads** give a small comfort amount, but only for your favourite
   genre.
5. **Real books** from the period are mixed in alongside vanilla's fictional
   titles.
6. **Vanilla only.** Only vanilla items are tagged. Books from other mods get
   a neutral fallback.
7. **This Is Your Life**: books you finish are logged to its survivor journal.
   The user wants that bridge in Dan's Vanilla Fixes.
8. **Hidden quality score** for every title. Better books give better buffs.
9. Vitality (DanTraits), Dan's Vanilla Fixes and the trait work are one
   project to the user, so where the code lives is our call. See "Where it
   lives".

## Vanilla facts (42.21, read 2026-10-12)

Paths are relative to `ProjectZomboid/media`. Java behaviour comes from
constant-pool reads of `projectzomboid.jar` (no JDK here), not from decompiled
source.

- **The action** is `ISReadABook` (shared/TimedActions). Entertainment items
  are `ItemType = base:literature` with `BoredomChange`, `StressChange` and
  `UnhappyChange`. For example, `Book_Fiction` is -50/-40/-40 and `ComicBook`
  is -30/-20/-20.
- **The relief arrives all at once at the end.** `complete()` calls the Java
  method `character:ReadLiterature(item)`, which applies the item's three
  changes, but only `if not self.isLiteratureRead`. `perform()` sets that flag
  from `character:isLiteratureRead(modData.literatureTitle)` and then calls
  `addReadLiterature(title)`. During the read, `update()` only stops
  unhappiness from rising above the value it had when you started.
- **Duration** (`getDuration`): `numPages * minutesPerPage / f`, where `f` is
  `1 / getMinutesPerDay() / 2`, which works out to in-game minutes.
  - Literature has `NumberOfPages <= 0`, so it counts as **5 pages**. That is
    about 10 in-game minutes, whatever the book.
  - The `base:fastread` tag makes the time a flat 50.
  - Fast Reader ×0.7, Slow Reader ×1.3, worn `Glasses_Reading` ×0.9,
    sitting ×0.9.
  - The sandbox `MinutesPerPage` defaults to 2.0.
- **Page progress** (`setAlreadyReadPages`) is tracked only for items with
  pages, per character **per item full type**. Every copy of `Book_Fiction`
  would share one counter, so we need our own bookmark keyed by title.
  - Vanilla resumes a read with `self:setCurrentTime(maxTime * startPage /
    pages)` in `start()`. We can use the same call.
- **Genres already exist.** `book_subject` on the item scripts, in
  `scripts/generated/items/literature.txt` (561 items), draws from **55
  `BookSubject` values**. Some examples: general_fiction, thriller, romance,
  horror, western, scifi, fantasy, crime_fiction, true_crime, classic, bible,
  occult, conspiracy, quackery, self_help, golf, baseball, childs. Magazines
  have 24 `magazine_subject` values.
- **Titles**: `IG_UI.json` has 1,198 `IGUI_BookTitle_*`, 224
  `IGUI_ComicTitle_*` and 168 `IGUI_MagazineTitle_*` entries. A book title
  reads like `"Trouble at the Brain Factory", by Piper M. McDade`.
- **The title-to-subject map is Java**: `zombie/scripting/objects/Book`
  registers each title with a cover type (HARDCOVER / SOFTCOVER / BOTH) and
  one or more `BookSubject`s, through `Registries.BOOK`. The item is named by
  `ItemCodeOnCreate.onCreateSubjectBook` (Java), which stores the title in
  `modData.literatureTitle`. Lua can reach some registries (vanilla uses
  `Registries.FLIER`, `.BROCHURE`, `.NEWSPAPER`). Whether `Book`'s fields can
  be read from Lua is unknown (S1).
- **The tooltip** is Java (`Literature.DoTooltip`). It shows boredom, stress
  and unhappiness bars and "has/has not been read". Our extra lines go
  through an `ISToolTipInv` wrap, the same way the Collection checklist and
  the laundry tooltip already do it.
- **Illiterate** characters can only "look at the pictures" of
  `base:picturebook` / `base:picture` items (13 picture books, plus comics
  and photos). We keep that rule.
- **Stat scales in 42.21**: boredom and unhappiness run 0–100, stress 0–1.
- **MP**: in B42, `complete()` runs on the server. Never wrap
  `ISReadABook:new` because MP reads its parameter names ([[mp-equip-hotfix]]).
  Wrap `getDuration`, `start`, `update`, `stop` and `complete` instead.

### This Is Your Life (Workshop 3773911887)

`TIYLMilestones.lua` writes life events as plain strings to
`player:getModData().TIYL.journal.timeline`, then calls `transmitModData()` in
MP. Appending our own lines there is enough to log books. The journal UI is in
`TIYLSurvivorJournal.lua`. S6 checks how it renders a timeline entry.

## The design

### Tags: every title gets four facts

| Tag | Source | Visible |
|---|---|---|
| **Genre family** | vanilla `BookSubject` / magazine subject, mapped to a family; comics tagged by hand | always, on the tooltip |
| **Length** (pages) | real page count for real books; for vanilla titles, a per-title value from a hash of the title inside a range set by cover and subject | always, as "Pages: 120 / 412" |
| **Quality** 1–5 | real books set by hand; vanilla titles from the hash, skewed so most land at 2–3 | hidden until you finish it |
| **Medium** | item type (novel, picture book, comic, magazine, newspaper, other print) | always |

The data lives in a generated Lua table (`*_ReadingData.lua`). A tool script
builds it from the game jar and the translation files, and a hand-edited
overrides file sits on top of it: real books, comic genres, notable quality
picks. Regenerating after a game update is one command.

### Genre families (what tastes pick from)

55 subjects are too many to have tastes about, so they fold into about 16
families. Every family has to be common enough in loot for a taste to matter.

| Family | Subjects |
|---|---|
| Horror | horror, occult |
| Thrillers & Crime | thriller, crime_fiction, true_crime, policing |
| Romance | romance, sexy, relationship |
| Sci-Fi & Fantasy | scifi, fantasy |
| Westerns | western |
| Popular Fiction | general_fiction, teens, quigley, hass |
| Classics | classic, classic_fiction, classic_nonfiction, play |
| History & War | history, military_history, military |
| True Stories | biography, adventure_non_fiction, sad_non_fiction |
| Sports | sports, golf, baseball |
| Faith | bible, religion |
| Fringe | new_age, quackery, conspiracy |
| Self-Help & Lifestyle | self_help, diet, fashion |
| Science & Nature | science, nature, medical, computer, farming |
| Arts & Screen | art, cinema, music, photo_special |
| Serious Reading | business, legal, politics, philosophy, general_reference, travel, school_textbook |
| Kids | childs, childs_picture_special |

(Kids is never picked as a taste. It reads at picture speed.) Magazine
subjects and comic genres map onto the same families. A horror comic is
Horror. A humor magazine goes to a "Humor" family that only exists for
comics and magazines.

### Taste

- At creation, each character rolls **one liked** and **one disliked** family,
  never the same one. Characters in existing saves roll theirs the first time
  they load. Later, Life Story's background can weight the roll.
- **Finding out**: after about 30 pages read in a family, the character
  reacts in halo text:
  - "You're really into this." (liked)
  - "Not your kind of book." (disliked)
  - "It's fine." (neutral)

  From then on, the tooltip shows the verdict for that family. Neutral
  families get found out too, so you can narrow down your tastes.
- **Multipliers on relief and on the finishing bonus**: liked ×1.25,
  neutral ×1.0, disliked ×0.5. A disliked book also adds a small boredom tick
  every 20 minutes or so. You can grind through it if nothing else is around.

### Relief while you read

- Relief is applied **per page read**, not per minute. That way Fast Reader
  gets more relief per hour, not less per book.
- **Base rates per page** come from the item's vanilla values, spread over a
  reference length:
  - Novel reference: 300 pages, so `Book_Fiction` gives -50 boredom, -0.40
    stress and -40 unhappiness for each 300 pages.
  - Magazines, comics and newspapers use their real short lengths, so their
    totals stay close to vanilla.
- Then: × taste × quality (0.8 / 0.9 / 1.0 / 1.1 / 1.2 for 1–5 stars).
- The rates are proposals to tune in the play-test. Stats stop at 0, so on a
  long book the relief mostly shows up as a long, steady period at 0 rather
  than a bigger number.
- **Vanilla's lump at the end is cancelled.** Our `complete` wrap snapshots
  boredom, stress and unhappiness, calls the original, then restores the
  three values. Everything else vanilla does is kept: read-tracking,
  map-revealing print media, recipes. Then we apply the finishing bonus.
- Vanilla's "unhappiness can't rise while reading" rule stays.

### Length and time

- Minutes per page: **novels 1.5, picture media 0.5**, scaled by the
  server's vanilla `MinutesPerPage` (×0.75 of it), so a server that changes
  that option changes ours too.
- A typical 350-page novel takes **~8.75 h** normally, **~6.1 h** with Fast
  Reader and **~11.4 h** with Slow Reader. Sitting and reading glasses still
  apply. That meets the user's "a novel in a day".
- Real books use real page counts. *It* runs about 1,100 pages, close to
  three days for a normal reader. That's the point.
- Vanilla title ranges, varied per title:

  | Kind | Pages |
  |---|---|
  | Softcover | 180–380 |
  | Hardcover | 250–500 |
  | Reference / Serious | 300–650 |
  | Kids | 24–64 |
  | Comics | 24–48 |
  | Magazines | 60–140 |
  | Newspapers | 12–40 |
  | Brochures / fliers | as vanilla |

- **Bookmarks**: progress is kept on the copy (`modData`) and also per
  character per title. If you put a book down, get interrupted or pick up
  another copy of the same title, you resume where you were. Each read is one
  timed action that ends when you stop, at a chapter you choose, or at the
  end. Short reads on an expedition are the intended use.
- **Read a chapter**: an extra context option, "Read a chapter (~30 min)",
  stops the action after about 30 minutes of pages. That suits the "sit down
  while catching your breath" use.

### Finishing a book

- A moodle named **Good Read**, positive, in three levels:
  1. Good Read: you finished it.
  2. Great Read: quality 4–5, or liked genre.
  3. **Loved It**: liked genre **and** quality 4–5. The user's +0.25 applies
     here, on top of the liked ×1.25.
- **Duration** is 24 h at quality 3 and 48 h at quality 5. It scales down to
  12 h for comics and magazines, which never go above level 1. Newspapers and
  fliers give no moodle.
- **Effect**: boredom builds 10–25% slower and unhappiness drifts down
  slightly. Then there is **one small buff matched to the genre**:

  | Family | Buff |
  |---|---|
  | Horror | panic builds 10% slower |
  | Thrillers & Crime | stress builds 10% slower |
  | Romance | unhappiness decays a little faster |
  | Sci-Fi & Fantasy | boredom builds a further 10% slower |
  | Westerns | endurance recovers 5% faster |
  | True Stories | stress decays a little faster |
  | Sports | +5% Fitness and Strength XP |
  | Science & Nature | +5% Foraging XP |
  | Self-Help & Lifestyle | +5% XP to all non-combat skills |
  | Faith | stress builds 5% slower and unhappiness decays a little faster |
  | Classics | the moodle lasts 25% longer |
  | the rest | the base moodle only |

  Every value is multiplied by the moodle level's strength. The table is a
  first draft to tune.
- **One moodle at a time.** A new finish replaces it if the new one is
  stronger and refreshes its duration otherwise.
- After finishing, the tooltip shows your verdict: "You thought it was
  great." That records quality for later re-read decisions and for the log.

### Re-reads

- A title you have already read gives **20% of the drip, only if it's in your
  liked family**. That's comfort reading. Other re-reads give nothing, as in
  vanilla.
- A re-read gives no moodle.

### Real books (1993 America)

- About 80–120 real titles published before July 1993, the game's date. Each
  has a title, author, real page count, a family, quality set by hand and a
  cover type. **Only titles and author names are used**: no text, no covers.
- Some candidates, with page counts to check against the first editions:
  - Thrillers: *Jurassic Park*, *The Firm*, *The Pelican Brief*, *The Silence
    of the Lambs*, *The Hunt for Red October*, *Red Storm Rising*, *Presumed
    Innocent*.
  - Horror: *It*, *Misery*, *The Stand*.
  - Westerns: *Lonesome Dove*.
  - Romance: *The Bridges of Madison County*.
  - Classics: *To Kill a Mockingbird*, *Catch-22*.
  - Fantasy: *The Hobbit*.
  - Popular fiction: *The Joy Luck Club*.
- **How they spawn**: an `OnFillContainer` hook gives a vanilla subject book
  a ~8% chance (sandbox option) to become a real book from the same family.
  It sets `modData.literatureTitle` to our own key, plus the item's name.
  Everything else (taste, length, read-tracking) then just works (S2, S3).

### The tooltip

New lines under vanilla's:
- **Genre**, with a ♥ or ✗ once you've found out how you feel about it.
- **Pages**, as read / total.
- **Your verdict**, once finished.

Vanilla's boredom/stress/unhappiness bars stay. They show the *full-book*
relief at your taste multiplier.

### Mods' books

Untagged literature from other mods gets the family "Popular Fiction"
(neutral for everyone), the vanilla 5-page length scaled to a 120-page short
read, quality 3, and no moodle. It still works and never errors.

## Where it lives

The proposal is **Dan's Vanilla Fixes**, as a self-contained module
(`DansVanillaFixes_Reading*.lua`), like laundry in Vitality.
- It overhauls a vanilla mechanic rather than adding a trait or a body system.
- It sits next to the Collection checklist, which already tracks books.
- The TIYL journal bridge the user wants in DVF then lives in the same mod as
  the events it logs.

Vitality hooks into it through an exported API (`DVF_Reading`). Hook ideas:
Homebody reads better at home, Concussion makes reading cause headaches,
Bad Day gets a comfort bonus, and age 40+ without reading glasses reads
slower.

A master sandbox toggle plus its own sandbox page, `DansVanillaFixesReading`:
- On/off
- Novel minutes-per-page scale
- Real-book chance
- Taste strength
- Moodle duration scale
- Re-read comfort on/off

## Code shape

- `shared/DansVanillaFixes_ReadingData.lua`: generated, title → {family,
  pages, quality, medium}.
- `shared/DansVanillaFixes_ReadingBooks.lua`: hand-edited real books, comic
  genres and overrides.
- `shared/DansVanillaFixes_Reading.lua`: core.
  - Lookups.
  - Taste roll and storage (`player:getModData().dvfReading`).
  - The per-page relief maths.
  - Bookmarks.
  - The finishing bonus.
  - Hooks for Vitality.
- `shared/DansVanillaFixes_ReadingAction.lua`: wraps `ISReadABook`
  `getDuration`, `start`, `update`, `stop` and `complete`, plus the "Read a
  chapter" variant. Never `new`.
- `client/DansVanillaFixes_ReadingClient.lua`: tooltip, context option, halo
  text, moodle.
- `client/DansVanillaFixes_TIYL.lua`: journal lines, only when This Is Your
  Life is active. For example: "Finished *Jurassic Park* by Michael Crichton.
  Loved it." and "Turns out I can't stand westerns."
- `tools/gen_reading_data.py`: reads `literature.txt`, `IG_UI.json` and the
  `Book` class's static initialiser from the jar, and writes the data file.
  It runs offline, and the output is committed.
- Tests: `tests/test_reading.lua` covers the taste roll, families, relief
  maths, Fast Reader vs normal, bookmarks, re-read comfort, moodle level and
  the fallback for mod books.

## Spikes before building

- **S1**: can Lua read `Registries.BOOK` (translationKey, subjects)? If so,
  generating at runtime could replace the tool script. Either way, the offline
  table stays for the test harness.
- **S2**: what `modData.literatureTitle` holds for books, comics and
  magazines (the translation key or the display text), and whether comics and
  magazines get one at all.
- **S3**: a real-book swap (`literatureTitle` + `setName` + `setCustomName`)
  survives save and load, and the vanilla tooltip and `isLiteratureRead` use
  our title.
- **S4**: snapshotting and restoring around `complete` cancels the lump
  cleanly in SP, and in MP on the server.
- **S5**: `setCurrentTime` resumes a literature read that has no
  `NumberOfPages`.
- **S6**: how the TIYL journal renders a timeline line (date prefix,
  wrapping).

## Phases

1. Data: the generator, families, lengths and quality. Tests on the table.
2. Long reads: duration, per-page relief, cancelling the lump, bookmarks and
   "Read a chapter". This is the biggest change in feel. Play-test here.
3. Taste: the roll, finding out by reading, the multipliers and the tooltip.
4. Finishing: the Good Read moodle, genre buffs and the verdict.
5. Real books: the list, the swap and the sandbox chance.
6. The TIYL journal bridge, then the Vitality hooks.

## Open questions

1. **"Especially loved"**: as drafted, Loved It means liked genre **and**
   quality 4–5, with +0.25 bonus strength. Or should it be a random "this one
   got to you" roll on any liked book?
2. **One liked and one disliked family, or two liked?** Two liked makes good
   reads more common. One keeps the find feeling rare.
3. **Should a long session wear off?** Hour five of the same book gives less
   than hour one. This was idea 2 in the brainstorm and it isn't in the
   user's plan. It's left out unless wanted.
4. **Genre buff table**: which buffs feel right? Self-Help's +5% XP to all
   non-combat skills may be too strong.
5. **The real-book list**: should I draft the ~100 titles next, for the user
   to cut?

## As built (2026-10-12)

Built as designed, in Dan's Vanilla Fixes (`DansVanillaFixes_ReadingData.lua`
generated, `_ReadingBooks.lua`, `_Reading.lua`, `_ReadingAction.lua`,
`client/_ReadingClient.lua`, `client/_TIYL.lua`, the sandbox page
`DansVanillaFixesReading`, the Good Read moodle and icon) plus Vitality's hooks
in `DanTraits_Reading.lua`. `tests/test_reading.lua` covers it offline. The
spikes were answered from the jar, not the game, so the in-game pass is still
owed:

- **S1**: not needed. `tools/gen_reading_data.py` walks the bytecode of the
  `Book`, `ComicBook` and `Magazine` static initialisers in the jar and pairs
  each title key with its cover and subjects. Regenerate after a game update.
- **S2**: `literatureTitle` is the registry's key with its prefix:
  `IGUI_BookTitle_<Key>` for books, `IGUI_ComicTitle_<Key>` plus an issue
  number for comics, `IGUI_MagazineTitle_<Key>_<month>_<year>` for magazines.
  The lookup strips the prefix and trailing numbers until the table knows it.
  Recent newspapers, HottieZ/HunkZ, catalogues and TV guides carry other keys
  and get the fallback (a newspaper is read as 12-40 pages with a small
  payoff of -10 boredom and -5 stress; the rest as picture media).
- **S3**: the real-book swap names the item the way `ItemCodeOnCreate` does
  (`setName`, `literatureTitle = IGUI_DVF_BookTitle_<Key>`). Save/load is
  untested in the game.
- **S4**: the snapshot and restore around vanilla's `complete` is built as
  designed; untested in MP.
- **S5**: avoided. No `setCurrentTime`: every session is its own action for
  the pages it will read (the rest of the book from the bookmark, or a
  chapter), so the progress bar shows this session.
- **S6**: a timeline line is `"<Month> <day>, <year> - <text>"` in the
  handwritten font, cut to the page width, using its own month keys.

Changes on the way:

- **Finishing**: a session that stops short hides `literatureTitle` from
  vanilla's `perform` and `complete`, so the game does not mark the title read
  after a chapter; a finished read lets vanilla mark it. Re-read status comes
  from our own record or vanilla's `isLiteratureRead`.
- **Genre buffs** are per-minute stat nudges (panic, stress, unhappiness,
  boredom, endurance) scaled by the moodle's strength; the XP ones use the
  game's `addXpMultiplier` at 1.05 over levels 0-10, only when no skill book's
  multiplier is running, and are put back to 1 at expiry. Self-Help's "all
  non-combat skills" became seven practical ones (Cooking, Farming, First Aid,
  Carpentry, Tailoring, Mechanics, Electrical).
- **One moodle**: a stronger finish replaces; a weaker one refreshes only if it
  would end later.
- **Taste notices**: the neutral one uses `HaloTextHelper.addText` with the
  good-text call as a fallback.
- **Vitality hooks**: Home (+15% relief by strength, +30% Homebody), Concussion
  (relief halved, pages a quarter longer, by strength), A Really Bad Day
  (+25% relief in the first 24 hours), 40s without reading glasses (+10%
  time), 50s (+15%). No concussion headache from reading (not built).
- **Open questions decided for now**: 1. Loved It = liked and four or five
  stars, +0.25 strength. 2. One liked, one disliked. 3. No wear-off in a long
  session. 4. The buff table as drafted, with the XP guard. 5. About 200 real
  titles drafted in `DansVanillaFixes_ReadingBooks.lua` (page counts from
  memory of the common editions; worth a check), for the user to cut.
