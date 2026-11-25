# Invite and profile (spec 06, in progress)

Status: partial. See the PR checklist for what is and is not done.

## Flow
- Owner opens the invite page (`/family/invite`, from the family tree header or
  the Family home card): short code (`7K4-QM9`), QR code, WhatsApp, share and
  copy buttons, and rotate code (owner only).
- The invited person opens the link (or types the code on the first-run
  screen). `/join/<code>` shows the family name and member count
  (`preview_family_by_code`) and joins only after a tap (`join_family_space_by_code`).
- After creating or joining a family the app asks once "What does the family
  call you?" when the person has no name. Cancel skips it; Settings > Account >
  Your name can set it later.

## Rules
- The code is validated in the app (`domain/invite_code.dart`) and again by
  the backend. Hostile input never reaches a query.
- The old UUID code still works (`join_family_space`).
- Names are 1 to 40 characters. Blank names show as "Family member".
- Migration `0011_profile_names.sql`: new profiles do not take the email
  prefix as a name. Existing rows are not rewritten (see `docs/backend.md`).

## Not done
Goldens and real-font renders for the invite and join screens, AC-8
integration test, invite entry from the empty family state and the person
sheet. The IdeaInvite artboard was not supplied, so the visual match is
unverified. Arabic copy is unreviewed.
