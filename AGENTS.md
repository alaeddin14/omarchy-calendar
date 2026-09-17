# Calendar fork

The checkout at `~/.config/omarchy/plugins/tmn73.calendar` is the working source
for the `alaeddin14/omarchy-calendar` fork. Keep the upstream plugin ID. Changes
here need a commit and push to the fork to reach other machines; do those only
when requested. Never commit local event data or credentials.

## Runtime and dependencies

- QML uses Omarchy's `qs.Ui` popup/widgets and `qs.Commons` theme primitives.
- Python sync is standard-library-only; run Python and tests through `uv`.
- `gws` needs the existing read-only Google Calendar profile. Personal machine
  installation belongs in config-files `omarchy/bash/functions/bar-plugins.sh`.
- The systemd timer fetches every five minutes. Each command is bounded to 45
  seconds and the whole service to four minutes. Failures preserve the cache.
- The popup must warn about stale data even when cached events are visible;
  the warning must age with `nowTick`, not a nonreactive `Date.now()` binding.
- Deploy service-template edits into the user systemd directory and reload
  systemd; editing the template alone does not update an installed unit.

## Validation

From this checkout:

```bash
PYTHONPATH=sync uv run --no-project python -m unittest discover -s tests -t . -v
node --test tests/model.test.js
omarchy plugin validate "$PWD"
```

After runtime edits run `omarchy restart shell`, verify
`omarchy-shell shell ping` returns `ok`, and open the calendar to check rendering.
For sync changes verify a real systemd sync succeeds and the timer stays enabled.
Inspect event counts/dates instead of printing private titles or raw responses.
For stale-state changes visually check a stale document containing events and
recovery to fresh data. Use isolated fixtures rather than replacing live data.
