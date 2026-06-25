---
name: hackathon-bugfix
description: "Diagnose and fix common hackathon app failures in React, Node.js or Go, MySQL, Docker, GitHub, and GCP setup. Use when a non-technical participant says the page is blank, a button does nothing, data is not saving, Docker will not start, MySQL is broken, the image build fails, the app crashes, or an error message is confusing."
---

# Hackathon Bugfix

## Overview

Convert vague symptoms into a concrete fix. Start with evidence, change the smallest thing that explains the failure, and confirm the app works again.

## Workflow

1. Ask for a screenshot or exact error only if logs cannot be collected locally.
2. Run `scripts/collect_diagnostics.sh` from the project root.
3. Read `references/common-failures.md` for likely causes.
4. Identify the layer: browser, React build, backend API, MySQL, Docker, Git/GitHub, or GCP.
5. Patch the smallest relevant set of files.
6. Re-run the failing command.
7. Explain the fix as "what was wrong" and "what works now."

## Safety

- Do not delete participant work to fix build errors.
- Do not reset git history.
- Do not wipe MySQL data unless the participant asks to clear test data.
- Do not add a new technology to bypass the real issue.

## Resources

- `scripts/collect_diagnostics.sh`: collect project, Docker, port, and log evidence.
- `references/common-failures.md`: fast map from symptoms to likely fixes.
