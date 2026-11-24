# Database & access-control design

Status: written and syntax-validated (pglast). **Not yet executed against a live
PostgreSQL/Supabase instance** — no project credentials exist yet. The RLS test
suite in `supabase/tests/rls_access_tests.sql` must run green before any
security claim is made.

## Entity map

```
auth.users 1---1 profiles
profiles 1---* family_memberships *---1 family_spaces
family_spaces 1---* persons
persons 0---1 profiles        (linked_user_id, optional, late-bound)
persons *---* persons         (relationships: parent/child/spouse/sibling, pending|confirmed)
family_spaces 1---* stories
stories *---* persons         (story_narrators, ordered; story_people, mentioned)
stories *---* photos          (story_photos)
photos *---* persons          (photo_people)
stories *---* profiles        (story_recipients: access grants)
```

Three separate concepts, per the product spec:

- **Account** = `auth.users` + `profiles`. Authentication only.
- **Person** = `persons`. A real individual in the family network. No account
  required; a deceased person is a normal row. `linked_user_id` connects a
  person to an account later, never automatically.
- **Story** = `stories` + join tables. Narrators are ordered and individually
  identifiable; no merging of perspectives.

Phone numbers and national IDs appear nowhere. UUIDs everywhere.

## Access model

Every story has `visibility`: `private` (default), `selected`, `family`.

The access rule is uniform and lives in `can_access_story(story_id)`:

> Access = creator, OR (current space member AND holds a grant row in
> `story_recipients`).

Grant rows are produced in exactly two ways:

1. **Selected sharing**: the creator inserts one row per recipient. The insert
   policy requires the grantor to be the story creator, the grantee to be a
   current member of the story's space, and `grantee <> grantor` (nobody can
   grant themselves).
2. **Family sharing**: the `stories_family_share_snapshot` trigger
   materializes the full member list at the moment the story becomes
   `family`. This is a snapshot, not dynamic whole-family access.

Revocation semantics, each covered by the test suite:

- A member is removed or leaves → `memberships_delete_revoke_grants` deletes
  their grant rows in that space → access ends immediately.
- Removal is an explicit owner action through `remove_family_member`
  (security definer RPC). It records a row in `family_membership_removals`,
  so a removed member CANNOT rejoin with the unchanged invite code:
  `join_family_space` rejects them with `member_removed`. The owner can lift
  a block deliberately (owner-only delete on `family_membership_removals`)
  and share the code again. A member who leaves on their own is not blocked
  and can rejoin with the code. A direct SQL delete of a membership (owner
  via the dashboard) records no block; the app always uses the RPC.
- Any member who (re)joins is a new member: no grants, no historical
  stories. Re-sharing (`visibility` toggled to `family` again) materializes a
  fresh snapshot including them.
- Changing a story back to `private`/`selected` stops all family access
  because `can_access_story` checks current visibility.

Join tables (`story_narrators`, `story_people`, `story_photos`) are readable
exactly when their story is readable, so metadata never leaks an inaccessible
story's existence.

**Photo permissions are fully independent of story permissions.** A photo is
visible to its uploader, or to a member holding a row in `photo_recipients`
(materialized by `materialize_family_photo_share` when the photo's visibility
becomes `family`, the same recipient-snapshot rule as stories). Linking a
photo to a story via `story_photos` never widens either audience: the link
row is readable with story access, but the photo row and its file require
photo access. A private photo attached to a family story stays invisible to
the family; a family photo attached to a private story stays visible to its
photo audience. Membership removal deletes photo grants exactly like story
grants, and rejoining restores neither.

Joining a space happens through `join_family_space(invite_code)` (security
definer RPC). Direct membership inserts are owner-only, so nobody can
self-join an arbitrary space id. Owners cannot read other members' stories:
`stories_select` never checks ownership of the space, only the story rule.

## Storage

Two private buckets, `story-audio` and `family-photos`, with size and MIME
limits at the bucket level. Member uploads are namespaced by uploader:
`{space}/{uploader}/{story-or-photo}/{file}` (directory avatars use
`{space}/persons/{person}/{file}`). Files are uploaded before their metadata
row exists, so the insert policy cannot check ownership; the uploader segment
must equal `auth.uid()`, which stops one member from occupying, replacing, or
enumerating another member's staging paths. Read policies map the path back
to the story/photo and apply the same access functions, so a predictable URL
is useless without authorization. The object owner can always read and delete
their own objects, which is the cleanup path for orphans after a failed
metadata insert; the app deletes the uploaded object when the story insert
fails. There is no update policy: objects are immutable and retries are
delete-then-insert.

**Signed-URL residual access (known limit, by design):** a signed URL, once
issued, is usable by its holder until expiry even if their access is revoked
immediately after. This cannot be revoked. Mitigation: the app issues URLs
with a 15-minute TTL and re-mints on demand. Do not raise the TTL to "make
playback smoother"; cache the file locally instead.

**Orphan objects (operational cleanup required before production):** an
object whose metadata row never got created is normally cleaned up by the
app (delete-after-failed-insert) or by its owner, who can always see and
delete their own objects while still a member. Two cases outlive that path:
the app dies between upload and row insert, and the uploader is removed from
the space before cleaning up (membership gates even the owner branch, so a
removed member's orphans become unreachable). Before production, add a
scheduled janitor: a security-definer function or dashboard SQL run by the
space owner that deletes storage objects whose `{story|photo}` path segment
has no matching row after a grace period (e.g. 24 hours). Until that exists,
these objects consume storage but are readable by no one.

## AI-ready extension points (not built)

Derived content must never bypass source permissions:

- `story_transcripts(story_id, text, engine, created_at)` — RLS: readable when
  `can_access_story(story_id)`.
- `story_summaries(story_id, text, engine, created_at)` — same policy.
- Generated content is always keyed to its source recording and labeled with
  the engine that produced it.

## Migrations

1. `20261123000100_schema.sql` — tables, constraints, indexes, helper
   functions, triggers (family-share snapshot, grant revocation, profile
   bootstrap).
2. `20261123000200_rls.sql` — RLS enabled and policies on all 12 tables.
3. `20261123000300_storage.sql` — private buckets, size/MIME limits, storage
   object policies with deny-on-parse-error path helpers.
