<!-- Big feature (new column + graph layout): owner review required. -->

# Spec 05 · Family tree graph and person sheet

Status: ready for review · PR title: `feat: interactive family tree with relationship ropes and person sheet`
Branch: `feat/05-family-tree` · Depends on: 01, 03 · Flag: `family_tree_graph` (on in dev/staging; owner turns it on in prod)

## Why

The family is the app's map: who is who, who has told stories, who hasn't
yet. A real tree the family can pan and zoom, where tapping anyone opens
their voices, turns the directory into the main way to explore stories.

## Design references

- Family tree (interactive): `#artboard-Family`. Press Play on the canvas:
  drag to pan, wheel/buttons to zoom, tap a person.
- Person sheet open: `#artboard-PersonSheet`
- Design System: PersonChip, Button, StateView

## Code to read first

`lib/features/family/**` (`family_tree_view.dart` exists: reuse what fits),
`lib/features/stories/data/**`, `supabase/migrations/0003_family_schema.sql`
(persons, relationships, family_memberships.person_id),
`supabase/migrations/0004_family_rls.sql`.

## Scope

### 1. Data

- Migration `0009_person_gender.sql`: `alter table persons add column gender
  text check (gender in ('female','male'))` (nullable). Ask for it, optional,
  when adding or editing a person ("So we can say grandmother or
  grandfather"). pgTAP: same access as other person columns.
- `FamilyGraph` (pure Dart, `lib/features/family/domain/family_graph.dart`):
  built from persons + relationships + memberships; knows parents,
  children, spouses, siblings, which person is "me"
  (`family_memberships.person_id` of the signed-in user), and each person's
  story count and minutes (accessible stories where they are a narrator).
- **Relation to me** (`kinship.dart`, pure, heavily tested): shortest path
  over confirmed relationships, mapped to a label with gender when known.
  English: mother, father, parent, grandmother, grandfather, grandparent,
  great-grandmother…, sister, brother, sibling, aunt, uncle, cousin, niece,
  nephew, daughter, son, granddaughter, grandson, wife, husband, spouse,
  mother-in-law, father-in-law, sister-in-law, brother-in-law, "relative"
  (fallback). **Arabic distinguishes sides**: خال/خالة (mother's side) vs
  عم/عمة (father's side), ابن/بنت خال/خالة/عم/عمة, حماة/حما, جد/جدة, تيتة
  is not used in the label (labels are formal; names already carry the
  nickname). Unknown gender → neutral form ("parent" / "والد أو والدة" → use
  "قريب" only if no neutral exists). Pending relationships are not used for
  the label; show "not confirmed yet".

### 2. Layout (`family_layout.dart`, pure, tested)

Rules that make the ropes readable (the reason this spec exists):
- Generations are rows; "me" is on the bottom-most row that has people
  unless descendants exist. Row height 220 (logical px at 100%).
- Couples sit side by side; **spouse distance ≥ widest label + 24 px** so the
  couple's knot is in a clear gap between the two names.
- Children of a couple are centred under the couple's knot, ordered by birth
  year then name; siblings 140 px apart minimum; subtrees never overlap
  (simple Reingold–Tilford-style packing is enough).
- People with no relationship yet go in a final row "Not connected yet" with
  a hint "Add how they're related".
- **Rope routing** (orthogonal, rounded corners r = 12): couple line at the
  circles' centre height between the two circles; from the knot straight
  down to a horizontal **bus line** placed in the empty band between the
  parents' labels and the children's circles; from the bus straight down
  into the top of each child's circle. Ropes never pass under a label (unit
  test: no rope segment intersects any label rectangle). Single parent: the
  rope starts under the parent's label instead of a knot.
- Confirmed ropes: 3 px `primary` at 70% opacity; pending: dashed
  `onSurfaceVariant`.

### 3. Tree screen (`FamilyTreePage` → `FamilyTreeView`)

Per artboard Family:
- Header: family name, "9 people · 31 stories", search (find a person: jumps
  and zooms to them) and invite (spec 06).
- Canvas: `InteractiveViewer` (min 0.5, max 1.8, boundary margin 200,
  double-tap zooms in 1.5× around the tap), dotted background, ropes painted
  by a `CustomPainter` **under** the node widgets. Opens centred on "me" at
  100%.
- Node: 68 px avatar (photo or initial on tint), ring = olive when the person
  has stories, dashed when none, thicker with a halo for "me"; count badge;
  name (`label`, one line, ellipsis at 120 px); relation to me (`caption`,
  `onSurfaceVariant`). Whole node ≥ 48 px tap target, semantics
  "Sitto Fatma, your grandmother, 12 stories".
- **Rope labels**: a pill on each child's drop ("daughter"/"son"/"child";
  Arabic بنت/ابن) and on each couple ("married"; pending: dashed pill). Pills
  and relation lines hide below 75% zoom and fade back in above it.
- Controls (end side): zoom in, zoom out, **Fit** (whole family), **Center on
  me**; a zoom % chip at the start. Legend at the bottom (has stories / no
  stories yet / not confirmed).
- Large families: only build node widgets inside the visible rect + margin;
  tested with 300 generated people at 60 fps in profile mode (report the
  number in the PR).
- States: loading (skeleton tree outline), empty ("Add the first person:
  start with yourself, then your parents"), error with Retry. Feature flag
  off → today's list view (keep it working).

### 4. Person sheet (tap a node)

Per artboard PersonSheet, opened with `showAppSheet`:
- Photo (88 px rounded), name (`headline`), relation to me, years and place,
  "12 voices · 41 min" (`primary`).
- **Play all** (primary): queues all this person's accessible stories in the
  shared player (add queue support to the spec 03 player: next/previous,
  auto-advance). **Record her/him/yourself** (secondary, record colour):
  opens Record with this person as narrator.
- **Topics**: chips with counts; tapping one filters the voices list.
- **Voices**: first 3 stories (play inline), "See all 12" opens the feed
  filtered by this narrator.
- No stories: the empty line with a suggested first question and the record
  button.
- Footer links: **Photos**, **Edit person**, **Add a relative** (existing
  flows, restyled).
- **Long press** on a node: the same three quick actions as a small menu
  (Record with, Add a relative, Edit), never anything that isn't also in
  the sheet.
- While the sheet is open, the ropes on the path between this person and
  "me" are drawn at full opacity and the rest dimmed to 30%.

## Acceptance criteria

- **AC-1** Migration 0009 + pgTAP pass; gender is optional in add/edit.
- **AC-2** `kinship.dart`: table-driven tests for at least 40 paths in both
  languages, including maternal/paternal Arabic forms, in-laws, unknown
  gender, pending relationships, and "me".
- **AC-3** `family_layout.dart`: tests for couples, single parents,
  remarriage (person with two spouses), siblings without parents,
  disconnected people, and the "no rope under a label" property over a
  generated 300-person tree.
- **AC-4** Tree screen matches artboard Family (goldens at 100% and 60% zoom,
  light/dark × en/ar); RTL mirrors the layout (start side = right).
- **AC-5** Pan/zoom/fit/center-on-me/double-tap and search-to-person work
  (widget tests with `InteractiveViewer` transforms).
- **AC-6** Tapping a node opens the sheet; dragging never opens it.
- **AC-7** Sheet matches artboard PersonSheet; Play all queues the right
  stories; topic chips filter; See all opens the filtered feed.
- **AC-8** Long-press menu offers exactly the three actions.
- **AC-9** Path highlight between the selected person and me (widget test on
  painter inputs).
- **AC-10** Performance note with numbers for 300 people in the PR.
- **AC-11** Integration test (demo style): open Family, pinch-zoom out, fit,
  tap Sitto, play all, close, long-press Hany, Record with.
- **AC-12** `docs/features/family.md` (new or updated) explains layout rules
  and kinship.

## Analytics

`family_tree_opened`, `family_tree_zoomed` {via: pinch|button|fit|center},
`person_sheet_opened` {has_stories}, `person_play_all`, `person_record_started`,
`person_long_press_action` {action}.
