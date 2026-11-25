# Family tree (spec 05, in progress)

Status: partial. See the PR checklist for what is and is not done.

## Layers
- `domain/family_graph.dart`: people, confirmed and pending relationships, story counts per narrator, kin paths.
- `domain/kinship.dart`: kin path to an ARB `kinshipLabel` select key. Arabic wording is unreviewed.
- `domain/family_layout.dart`: pure Dart layout (generations, couples, mirrored for RTL, ropes, label metrics). Geometry is tested without widgets.
- `presentation/family_tree_canvas.dart`: pan and zoom (0.5 to 1.8), nodes virtualized, pills hidden below 75%.
- `presentation/family_tree_page.dart`: header (name, counts, search), loading, empty and error states.
- `presentation/family_tree_providers.dart`: `familyGraphProvider` and the flag provider.

## Feature flag
`family_tree_graph` is always on in dev and staging. In production it follows the remote flag (off until the owner turns it on). When off, the family screen keeps the previous list and simple tree.

## Known gaps
Person sheet, play-all queue, long-press menu, photos on nodes, goldens, AC-10 performance and the AC-11 integration test are not done. Great-aunts, step relations and long paths show "Relative".
