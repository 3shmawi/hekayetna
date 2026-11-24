-- Spec 04: a story's waveform (up to 128 values, each 0-100), computed on
-- the phone while recording. The player draws it; null means "not recorded"
-- (older stories). RLS is unchanged: the column lives on `stories`, so the
-- existing policies (read by visibility, write by creator) apply.
alter table public.stories
  add column if not exists waveform smallint[]
  check (
    waveform is null
    or (
      array_length(waveform, 1) <= 128
      and 0 <= all(waveform)
      and 100 >= all(waveform)
    )
  );
