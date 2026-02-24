# Agent Control Standard (A.C.S.)

A.C.S. in this repo uses three core files:
- `.ops/mission.yaml`: current mission, acceptance criteria, and constraints.
- `.ops/status.json`: machine-readable checkpoint status.
- `.ops/journal.md`: append-only execution notes and next actions.

For ChatGPT collaboration, only paste:
- `.ops/mission.yaml`
- `.ops/status.json`
- last 30 lines of `.ops/journal.md`
- and only if needed: one `.artifacts/*.log` file path
