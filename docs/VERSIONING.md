# Tiny Demons Versioning

Status: current release numbering rule

Updated: 2026-10-01

The current game version is `0.3.24`.

Every commit pushed to `main` must include a version update of at least
`0.0.01`. The version must be updated in both locations below in the same
commit:

- `scripts/screen_state_controller.gd` (`GAME_VERSION`), which renders in the in-game title menu and the homescreen/web build.
- `README.md`, under **Play in your browser**.

Use semantic-style `MAJOR.MINOR.PATCH` numbering. Normal development changes
increment the patch component; larger milestones may increment minor or major
as appropriate, but never reuse a version for a new push.
