# Collection checklist (Dan's Vanilla Fixes)

Status: built 2026-10-09 (Dan's Vanilla Fixes), deployed, not play-tested.

## The problem

Each character slowly gathers skill books, recipe magazines, VHS tapes, key
rings and other collectibles. After a few weeks nobody remembers which Carpentry
volume is already on the shelf at the base, so you either carry home duplicates
or leave behind the one you were missing.

## What the player gets

- **A sidebar button** (a clipboard with a tick) below the vanilla buttons opens
  the **Collection** window.
- **The window** has one tab per category, each with a count ("37 / 120"), a
  search box and a "Hide collected" toggle. Each row has the item icon, the name
  and a checkbox you tick yourself. Nothing is ticked automatically.
- **Right-click** any item on the list, in an inventory or a container:
  "Add to collection" / "Remove from collection" (applies to every selected item).
- **Tooltip**: a strip under the vanilla tooltip, green "✓ In your collection",
  or grey "Not in your collection yet" for an item on the list that isn't ticked.
- **Ticking an item type also sets it Unwanted** (vanilla B42 feature): every
  copy goes grey in inventories, "Take all" and "Take same type" skip it, and
  the vanilla tooltip says Unwanted.
- **One checklist per character.** A new character starts with an empty list.

## Categories (user's choice, 2026-10-09)

| Tab | What | How it's found | Vanilla count |
|---|---|---|---|
| Skill Books | Volumes 1-5 per skill; one row per skill, five boxes | literature with `SkillBook[getSkillTrained()]` (vanilla ISLiteratureUI's test) | 120 (24 skills) |
| Magazines | Recipe magazines | literature with `getLearnedRecipes()` | ~150 |
| VHS (Retail) | Films and TV, **per title** | `RecordedMedia` category `Retail-VHS` | 155 |
| VHS (Home) | Home recordings, **per title** | `RecordedMedia` category `Home-VHS` | 128 |
| Key Rings | `KeyRing_*` mementos | DisplayCategory Memento, type starts `KeyRing_` | 17 |
| Mementos | Every other Memento item (medals, Spiffo gear, band tees, masks, photos...) | DisplayCategory Memento | ~200 |
| Tools (added 2026-10-09) | Hand tools, tools that double as weapons, garden tools | DisplayCategory Tool, ToolWeapon or GardeningWeapon, minus debug items, raw tobacco, seed paste and unfired clay | 135 |

The lists are built once from the game's item scripts when the game starts, so
books, magazines, tapes and mementos from other mods appear too. Skill books use
the same hidden list as vanilla's (`ISLiteratureUI.SetItemHidden`).

## VHS tapes are the exception

**Wrong, corrected 2026-11-09** (user: tapes are not set Unwanted, fix it).
`InventoryItem.isUnwanted(player)` in the jar asks the player about, in order:
the media id of recorded media, the copy's `literatureTitle`, its `printMedia`
table (as a string, so never a match), its `collectibleKey`, and only then the
item type. So `player:setUnwanted(mediaId, true)` greys one title, and ticking a
tape or CD now does that (`media[id]` = WE_SET | WAS_SET; data `v = 2`, a v 1
character's ticked tapes are set on the first read). The same goes for titled
reading: see the 2026-11-09 section. What was built on 2026-10-09:

Every retail tape is the same item type (`Base.VHS_Retail`); the film is in the
item's media data (`item:getMediaData():getId()`). Unwanted works by item type,
so setting it would grey out **every** tape. So for tapes:

- the checklist, right-click and tooltip strip work per title;
- **no Unwanted**: tapes you already own are not greyed and "Take all" still
  takes them. The tooltip strip is how you tell.

CDs (69 titles) work the same way and get their own tab (user, 2026-10-09).

## Vanilla facts this relies on (42.21)

- `IsoPlayer:setUnwanted(fullType, bool)` / `isUnwanted(fullType)`, stored in
  the player's mod data under `itemUnwanted:<fullType>` and transmitted.
  `InventoryItem:setUnwanted(player, bool)` / `isUnwanted(player)` wrap it.
  Context menu: `ISInventoryPaneContextMenu.onUnwanted`. Text colour and the
  Take All handlers read it.
- Vanilla already has a **Literature** window (character screen) listing what
  you have *read*, magazines, recipes and media *watched*. Ours is what you
  *own*; we copy its item tests, not its window.
- The sidebar (`ISEquippedItem:initialise`) builds its buttons top to bottom and
  is rebuilt when the sidebar size option changes. Icons come in 48/64/80/96/128.
- Tooltips are drawn in Java; we draw the strip under them the way
  `DanTraits_InsulinInfo.lua` does (wrap `ISToolTipInv.render`).

## How Unwanted and the checklist interact

The checklist drives Unwanted, not the other way round (user's choice):

- Tick → `setUnwanted(type, true)`, and we remember that **we** set it.
- Untick → clear Unwanted **only if we set it**. If you had marked it Unwanted
  yourself before ticking, it stays Unwanted.
- Marking something Unwanted from the vanilla menu does not tick it.

## Data

Player mod data `DVF_Collection`:

```
{ v = 1,
  items = { ["Base.BookCarpentry2"] = 1 },   -- 1 = we set Unwanted, 2 = it was already Unwanted
  media = { ["<media id>"] = true } }
```

Fine for multiplayer as far as we can tell (mod data + vanilla's own
transmit), but Dan's Vanilla Fixes is singleplayer-only for now and this isn't
tested in MP.

## Files

- `shared/DansVanillaFixes_Collection.lua`: store (has/set/toggle, the Unwanted
  rule), the category list builder, `DVF_Collection.isListed(item)`.
- `client/DansVanillaFixes_CollectionUI.lua`: the window (ISCollapsableWindow +
  ISTabPanel + scrolling lists).
- `client/DansVanillaFixes_CollectionClient.lua`: sidebar button, context menu,
  tooltip strip.
- `media/ui/DVF/Collection_{On,Off}_<width>.png`: sidebar icon at the five
  sidebar sizes, drawn by `DansVanillaFixes/tools/make_sidebar_icon.py`.
- `Translate/EN/IG_UI.json` + `ContextMenu.json`: strings. RU left for the
  translator.
- `tests/test_collection.lua`: tick/untick, the "only clear what we set" rule,
  VHS by id, the list builder against mocked scripts.

## Out of scope

- Auto-ticking from what you've read or what's in your base.
- Comics and other per-title literature (no stable id found yet).
- A shared checklist between characters or players.
- A keybind (can be added later).

## Decided

1. CDs get a tab (user, 2026-10-09).
2. The grey "Not in your collection yet" line stays (user, 2026-10-09).

## Built differently from the plan

- Magazines: literature that teaches recipes, minus seed packets (vanilla
  lists seed packets as recipe books; they're DisplayCategory Gardening or
  named `*BagSeed*`).
- Mementos leave out `*_Reverse` (a reversed cap is the same cap).
- Media tabs use vanilla's names (VHS, Home VHS, CD), in the game's category
  order: CD, Home VHS, VHS.
- The window remembers where it was for the session only; vanilla's layout
  manager would restore a saved "closed" state onto a freshly opened window.
- Sidebar icon: `DansVanillaFixes/tools/make_sidebar_icon.py` writes
  `media/ui/DVF/Collection_{Off,On}_<width>.png`.

## Added 2026-11-09: all of the game's reading (user asked)

Five tabs after Recipe Magazines (the old Magazines tab, renamed): Books,
Magazines, Comics, Newspapers, Fliers. Kept by title like the tapes. Unwanted
is set by the string on the copy: from the list for a title every copy carries
the same string for (`entry.exact`), from the copies Add to collection was
chosen on for a dated magazine or a numbered comic; `marks` records what the
checklist set.

- What the game writes on a copy (`ItemCodeOnCreate` in the jar), item mod data
  `literatureTitle` unless noted:
  - book: `IGUI_BookTitle_<id>` (the translation key)
  - magazine: `IGUI_MagazineTitle_<id>_<month>_<year>`; TV guide `TVMagazine_m_y`;
    HottieZ `HottieZ_m_y` or `HunkZ_m_y`
  - comic: `IGUI_ComicTitle_<id>` or `IGUI_ComicTitle_<id>#<issue>`
  - catalogue `Catalog_IGUI_<id>`, RPG manual `RPGmanual_IGUI_RPG_<id>` (item type in front)
  - dated newspaper, flier, brochure: `Print_Media_<id>_title` (and a `printMedia` table)
  - old newspaper: `collectibleKey` = its whole translated name ("Newspaper: Knox Knews"),
    no `literatureTitle`
  - photos carry both keys but are unique per copy; they stay mementos by type
- My choices, not asked: magazines and comics count by name, not by issue (issues
  are random dates and numbers, the list could never be finished); RPG manuals sit
  in Books and catalogues in Magazines to keep the tab count down; schematics,
  crosswords, the phone book, paper and junk documents are left off.
- The registries (`Registries.BOOK` and so on) are reachable from Lua but the
  classes in them are not exposed, and `ResourceLocation` lower-cases the id, so
  the keys cannot be rebuilt in game: `tools/gen_collection_titles.py` reads the
  class constants from the jar and keeps the ones the English translation has a
  key for (the translation alone lists 12 books the game never registers).
  42.x at the time: 1,187 books, 16 RPG manuals, 167 magazines, 56 catalogues,
  224 comics, 22 old newspapers, 22 dated issues, 111 fliers, 22 brochures.
- Not checked in game yet.

### 2026-11-10: Vitality's real books (user: "paperbacks don't work")

The two paperbacks that had no Add to collection in the user's save were
"Mere Christianity" and "Love Story": Vitality's real books, not vanilla
paperbacks. Its reading (`DanTraits_Reading.lua`, `R.maybeReal`) swaps a novel
for a real one as loot spawns and writes `IGUI_DVF_BookTitle_<key>` on the copy,
a key with no translation and on none of the lists, and no adoption prefix
matched it. Vanilla paperbacks were fine (same `onCreateSubjectBook` and keys as
hardbacks).

- With Vitality loaded, its reading on and `ReadingRealBookChance` above 0, the
  203 rows of `DanTraits_ReadingData.real` are listed in Books as "Title, by
  Author" (`IGUI_DVF_Collection_BookBy`), `exact` = the key, so they are set
  Unwanted like any book.
- Otherwise they are not listed (they cannot be found), and a copy from before
  is adopted on sight (`C.TITLE_ADOPT` has the prefix), named from the table,
  or after the copy without the table.
- Read softly: Dan's Vanilla Fixes still loads without Vitality.
