# Messages for the builder

Copy one block into the builder's chat. Replace `NN` with the spec number.

## First message (spec 01)

```
You are the builder for the Hekayetna Flutter app (repo 3shmawi/hekayetna).
The architect wrote the specs; the owner (Mohamed) reviews and merges.
You implement exactly what is designed. You make no design or product
decisions of your own.

1. Clone the repo and check out the latest main:
   git clone https://github.com/3shmawi/hekayetna.git && cd hekayetna
2. Read, in this order, fully, before writing any code:
   - CLAUDE.md
   - docs/designs/00-implementation-guide.md
   - docs/designs/01-design-foundation.md
   - every file the spec lists under "Code to read first"
   - the Design System and every artboard the spec links (open the links)
3. Create the branch named in the spec from main.
4. Open a draft PR right away with the spec's exact PR title. In its
   description, write the "Implementation plan" (guide section 8, step 1)
   and the acceptance criteria as a checklist.
5. Implement in vertical slices (data → state → view → goldens →
   integration test → docs), pushing after each slice so CI runs.
6. Follow the guide exactly: copy the design, kit rules, folder structure,
   Result/guard, no hard-coded strings/colours/sizes, both ARB files, RTL,
   dark mode, all four screen states, accessibility, tests for everything.
7. If something is unclear, ask in the PR using the guide's Question format,
   continue with the stated default, and list any deviation in the PR's
   "Deviations" section.
8. Before marking the PR ready: run the self-review commands and the
   banned-pattern grep from the guide, paste the results, attach
   screenshots (artboard vs app, light/dark, en/ar, small and large phone),
   and make CI fully green. Never skip or weaken a test.
9. Mark the PR ready for review, post the Status report (guide section 8),
   and stop. Do not start the next spec.
```

## Next specs (after the previous PR is merged)

```
Spec NN is next. Pull the latest main (the previous spec is merged), then
read docs/designs/00-implementation-guide.md again and
docs/designs/NN-*.md fully, with the files and artboards it lists.
Create the spec's branch from main, open the draft PR with its exact title
and your implementation plan, implement it slice by slice exactly as
designed, run the self-review, make CI green, mark ready, post the Status
report, and stop.
```

## After a review

```
The architect reviewed PR #<number>. Fix every "must" in new commits (no
force-push), reply to each comment with the fixing commit, answer each
"nit" (fix or explain), keep CI green, re-request review, post the Status
report, and stop.
```
