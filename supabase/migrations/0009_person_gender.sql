-- Spec 05: optional gender on a person, so the app can say grandmother or
-- grandfather. Nullable; only 'female' or 'male'. RLS is unchanged: the column
-- lives on `persons`, so the existing policies apply.
alter table public.persons
  add column if not exists gender text
  check (gender in ('female', 'male'));
