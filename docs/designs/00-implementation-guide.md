# Implementation guide: read this before any spec

Status: ready for review · written 2026-11-24

This guide is for the engineer or coding agent that implements the specs in
this folder (`01-…` to `10-…`). Every spec assumes everything here. When a
spec and this guide disagree, the spec wins for that feature; when either
disagrees with `CLAUDE.md`, `CLAUDE.md` wins and you say so in the PR.

## 1. How the work flows

1. Work on **one spec per pull request**, in number order, unless the owner
   says otherwise. Never start spec N+1 on top of an unmerged spec N branch;
   wait for the merge, then branch again from the latest `main`.
2. Before writing code:
   - Read `CLAUDE.md` fully, then this guide, then the spec.
   - Open the design links the spec names and look at every artboard it
     lists, in both themes and both languages where they exist.
   - Read the files the spec lists under "Code to read first".
   - If something in the spec is impossible or contradicts the code, stop and
     ask in the PR description or an issue. Never guess silently.
3. Branch: `feat/<spec-number>-<short-name>` (for example
   `feat/02-recording-recovery`) from the latest `main`.
4. Commit in small Conventional Commits (`feat:`, `fix:`, `test:`, `docs:`).
5. Open a **draft PR** early, titled exactly as the spec's "PR title".
   Fill `.github/pull_request_template.md`. Put screenshots (light + dark,
   English + Arabic, small and large phone) in the description.
6. Make CI green: format, analyze, all tests, coverage ≥ the gate, security
   job, Android build. Never skip, disable or loosen a test or lint to get
   green.
7. Mark the PR ready and stop. The owner reviews and merges. Address review
   comments in new commits on the same branch.

## 2. Build exactly what is designed: no improvisation

The builder implements; it does not design. Every visual and product
decision is already made in the artboards, the Design System and the spec.

- **Copy the artboard exactly**: same elements, same order, same copy (the
  English and Arabic text in the artboards and specs are the ARB values),
  same colours (by token), same sizes and spacing (by token), same states.
  When in doubt, measure the artboard (open it on the canvas and inspect).
- **Do not add, remove, rename, reorder or "improve"** anything: no extra
  buttons, animations, icons, copy, settings or screens that the spec or
  artboard doesn't show. No new colours or text styles.
- **Missing detail** (a state the artboard doesn't draw, an icon not named):
  use the Design System's rule for it (README + component cards). If the
  Design System doesn't cover it, ask with the question format in section 8
  and use the stated default; never invent a new look.
- **Screenshots prove it**: each PR shows the artboard next to the app
  screenshot for every screen, light/dark, en/ar.

## 3. Code structure (clean, predictable, the same in every feature)

```
lib/features/<feature>/
  data/
    models/<thing>.dart              immutable models, fromJson/toJson, ==/hashCode
    <thing>_repository.dart          abstract interface, returns Future<Result<T>>
    supabase_<thing>_repository.dart backend implementation (guard() on every call)
    demo_<thing>_repository.dart     in-memory demo data
  domain/                            pure Dart rules only when a spec asks (kinship, layout)
  presentation/
    <screen>_page.dart               thin: reads providers, passes data + callbacks
    <screen>_view.dart               pure UI: data + callbacks in, no providers
    <thing>_controller.dart          Riverpod Notifier / AsyncNotifier (state + actions)
    widgets/<widget>.dart            feature-only widgets (shared ones go to lib/core/ui)
```

- One public widget or class per file; files under ~300 lines (split views
  into `widgets/`). Names say what things are (`StoryFeedView`, not
  `Screen2`).
- Providers for a feature live in `presentation/<feature>_providers.dart`;
  repository providers stay in `lib/app/app_providers.dart`.
- Views never call repositories or `Backend`; controllers never build
  widgets; repositories never import Flutter UI.
- No `dynamic`, no `as dynamic` casts, no `!` on values that can really be
  null, no `late` without a reason, no `print`. `very_good_analysis` stays
  clean with no new `// ignore`.
- Errors are values (`Result`), not exceptions, outside `data/`.
- Every public class and non-obvious method has a one-line `///` doc saying
  why it exists.

## 4. Ground rules from the kit (non-negotiable)

- Flutter is pinned in `.fvmrc` (3.47.9). Use `fvm flutter …` if FVM is
  installed. Do not change the pin or add dependencies unless the spec says
  so; when a spec adds a package, pin an exact version that has been out for
  at least two weeks and say why in the PR.
- Architecture: `lib/features/<feature>/data/` + `presentation/`. Pages are
  thin (`*_page.dart` wires state to a `*_view.dart` that takes data and
  callbacks only). State holders are Riverpod `Notifier`s.
- Repositories never throw to the UI: every call is wrapped in
  `guard(() => …)` and returns `Future<Result<T>>` (`Success` / `Failed`),
  see `lib/core/network/result.dart`. New failure kinds go in
  `lib/core/network/app_failure.dart` with a message in both ARB files.
- Backend calls only from `data/` sources via `Backend.client`.
- Screens are built only from `lib/core/ui/app_ui.dart` (`AppScaffold`,
  `AppCard`, `AppIconButton`, `showAppSheet`, …) and the shared widgets
  spec 01 adds. No `Scaffold`, `AppBar`, `SnackBar`, `Icons.x`,
  `FloatingActionButton` or raw Material widgets in feature code. Messages
  use `showAppMessage`. Icons come from `AdaptiveIcons`.
- No hard-coded strings, colours, text styles or sizes in feature code:
  strings in `lib/l10n/app_en.arb` **and** `app_ar.arb` (`context.l10n.key`);
  colours from `Theme.of(context).colorScheme` / `AppColors`; text from
  `AppTextStyles`; sizes from `AppDimens` with flutter_screenutil
  (`.w .h .sp .r`, design frame 375×812).
- RTL-safe: `EdgeInsetsDirectional`, `AlignmentDirectional`, start/end.
  Icons that point (back, forward, play) mirror in Arabic.
- Every screen has **loading** (skeletons, not spinners), **empty**,
  **error with Retry** and **offline** states (`LoadingView`, `EmptyView`,
  `ErrorView` from `lib/core/widgets/state_views.dart`, extended by spec 01).
- Accessibility: tap targets ≥ 48, text contrast ≥ 4.5:1, semantics labels on
  every icon-only button, works at 200% text size without clipping. Every
  screen widget test calls `await tester.expectAccessible()`.
- Button, chip and tag labels never wrap to a second line; long extra
  information goes in a line of text next to the button, never inside it.
- Analytics: `Analytics.capture('object_verb', {...})`, snake_case, no
  personal data (no names, emails, story titles, transcripts). List every
  event in the feature doc.
- Risky or unfinished features sit behind `FeatureFlags.isEnabled(Flags.x)`;
  add the flag in `lib/core/feature_flags/feature_flags.dart`.
- Routes: paths in `AppRoutes`, a unique snake_case `name:` on every
  `GoRoute`, documented in `docs/deep_links.md`, a hostile-input case in
  `test/security/deep_link_test.dart`.
- Supabase: schema changes only in a **new** file
  `supabase/migrations/00NN_<name>.sql` (never edit an applied one). RLS on
  every table. Every new table or policy gets pgTAP tests in
  `supabase/tests/` proving what `anon`, a member, a non-member and a removed
  member can and can't do. Run them locally with
  `supabase db start && supabase test db` (Docker).
- Never put secrets in the repo, env files or the app. Only publishable keys.

## 5. The design

- **Design System** (tokens, components, guidelines):
  <https://claude.ai/artifact/3DTUAPe6vLSCwpSGRNhCv1>. Its `README.md` and
  `tokens.json` are the source of truth for colours, type, spacing, radii and
  component behaviour.
- **Screens** (Design canvas): <https://claude.ai/artifact/B5gEE7QpXmeEE4EPiUDuw1>.
  Page "Screens" holds the approved app screens; page "Ideas" holds the
  feature ideas (specs 07–10). Artboard links have the form
  `https://claude.ai/artifact/B5gEE7QpXmeEE4EPiUDuw1#artboard-<Name>`.
- The designs are HTML mockups at 390×844. Match their layout, hierarchy,
  copy, colours and sizes; build them with Flutter widgets from the Design
  System, not by copying CSS. Where a mockup and the Design System differ,
  follow the Design System and note it in the PR.
- Sample names in mockups (Sitto Fatma, Giddu Ali, Omar…) are demo content:
  use them only in `Demo*Repository` data and goldens.

## 6. Tests every PR ships

| Kind | Where | What |
|---|---|---|
| Unit | `test/features/<f>/data/`, `…/presentation/` | repositories (Success and each Failed path), Notifiers (every state transition), pure helpers |
| Widget | `test/features/<f>/presentation/` | every screen and non-trivial widget via `tester.pumpApp`, all four states, RTL, `expectAccessible()` |
| Golden | `test/golden/golden_test.dart` | every new screen, light/dark × en/ar; update with `flutter test --update-goldens test/golden` and look at each PNG |
| Integration | `integration_test/` | the feature's main flow, written as a demo with `beat(tester)` pauses (`integration_test/helpers/demo.dart`) |
| Security | `test/security/`, `supabase/tests/` | new routes (hostile ids), new tables/policies, hostile user input (empty, 10 000 chars, `'; drop table`, `<script>`, RTL override characters) |

Coverage must stay at or above `COVERAGE_MIN` (`scripts/coverage_check.sh`).

## 7. Docs every PR updates

- `docs/features/<feature>.md` (start from `./scripts/new_feature.sh <name>`
  when the feature is new): what it does, screens, states, analytics events,
  "Decisions & edge cases" linking the spec, "Demo & post" section.
- `docs/README.md` links the feature doc.
- `docs/deep_links.md` for new routes; `docs/backend.md` for new tables or
  functions; `docs/security.md` for new data or permissions;
  `website/` privacy policy and `store/play_app_content.json` when the app
  collects new data or uses new permissions.

## 8. Roles and the review loop

There are three roles:

- **Owner** (Mohamed): decides product questions, approves specs by merging
  them, merges feature PRs.
- **Architect** (the Claude session that wrote these specs): owns the specs,
  reviews every PR against its spec and this guide, answers questions,
  updates specs when a decision changes.
- **Builder** (you): implements one spec per PR exactly as written.

### How the builder works, step by step

1. **Plan first, in the PR.** Within your first push, the draft PR
   description holds an "Implementation plan": the files you will add or
   change, the widgets and providers you will create, the migration (if
   any), and the tests you will write, each mapped to a numbered acceptance
   criterion of the spec. The architect may comment on the plan before you go
   far.
2. **Work in vertical slices.** Data layer + its tests → state holder + its
   tests → view + widget tests → goldens → integration test → docs. Push after
   each slice so CI runs early. Never leave a slice with failing tests on
   the branch tip for more than one push.
3. **Check off as you go.** Keep the spec's acceptance criteria as a
   checklist in the PR description and tick each one when it is done and
   tested. Name the test that proves each criterion.
4. **Questions.** When the spec is unclear, ask in the PR with this format,
   then continue with the stated default so you are never blocked:

   > **Question (AC-3):** … · **Options:** A …, B … · **Default I'm using:** A, because …

5. **Deviations.** Any change from the spec, the design or this guide goes in
   a "Deviations" section of the PR description with the reason. A deviation
   that isn't listed there is treated as a bug in review.
6. **Self-review before asking for review.** Run, and paste the results
   into the PR:
   `dart format --output=none --set-exit-if-changed $(git ls-files '*.dart')`,
   `flutter analyze`, `flutter test --coverage`,
   `./scripts/coverage_check.sh`, and (backend specs)
   `supabase test db`. Then grep your diff for the banned patterns:
   `Scaffold(`, `AppBar(`, `SnackBar(`, `Icons\.`, `Colors\.`,
   `EdgeInsets\.(only|fromLTRB)`, `fontSize:` literals, `TextStyle(` outside
   `app_text_styles.dart`, `print(`. Each hit is either removed or justified
   in "Deviations".
7. **Ready for review.** Mark the PR ready only when CI is green and every
   acceptance criterion is ticked. Then stop and wait; do not start the next
   spec.

### How the architect reviews

The architect reviews each ready PR in this order and leaves numbered
comments marked **must** (blocks merge) or **nit** (optional):

1. Every acceptance criterion: is it met, and does a test prove it?
2. Data safety: RLS and pgTAP for any backend change, no data loss paths,
   no personal data in logs or analytics.
3. Kit rules from section 4 and code structure from section 3 (the grep list in section 8, `Result`/`guard`, states,
   l10n, RTL, accessibility).
4. Visual match with the artboards (screenshots in the PR), both themes,
   both languages, small phone (375×667) and large phone (430×932).
5. Tests: meaningful assertions, not just "pumps without error".

### How the builder handles review

- Fix every **must** in new commits (never force-push a reviewed branch),
  reply to each comment with the commit that fixes it, and re-request review.
- A **nit** you disagree with: reply with the reason; don't silently ignore it.
- After two review rounds on the same point, the architect decides or asks
  the owner.

### Status report

Whenever you stop (ready for review, blocked, or end of a session), post a
PR comment in this shape:

```
Status: ready for review | blocked | in progress
Done: AC-1, AC-2, AC-4 (tests: …)
Left: AC-3 (why)
CI: green | red (job, cause)
Questions: none | see comment …
Deviations: none | see description
```

## 9. Definition of done (copy into the PR)

- [ ] Matches the named artboards in light/dark and en/ar; screenshots attached
- [ ] Loading / empty / error (Retry) / offline states
- [ ] No hard-coded strings, colours, sizes; both ARB files; RTL checked
- [ ] Repositories return `Result`; no raw Material widgets or `Icons.x` in features
- [ ] Unit + widget + golden + integration + security tests; CI green
- [ ] Feature doc, deep links and backend docs updated; analytics listed
- [ ] `flutter analyze` clean, `dart format` applied
