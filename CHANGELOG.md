# Changelog

## v1.0.2 — 2026-11-01

- Treat physical punctuation after **two lowercase Latin characters** as explicit English input, not a native Chinese Quick punctuation event.
- Preserve repeated literal punctuation (`wo...`, `wo+...`); return to regular Quick composition on the next letter.
- Retain original Chinese number-row selection, Shift+number associations, Left Shift, NumPad, and two-code Space behavior. Chinese candidates must be selected before punctuation.
- Windows QA preview produced expected `wo...`, `wo+...`, `of,`, and `你們`. GitHub CI includes 101,561 two-letter punctuation mocked-Rime assertions; compatibility across all Windows applications and keyboard layouts is not claimed.

## v1.0.1 — 2026-11-01

- Fix one-letter English followed by physical main-keyboard punctuation, including `a,`, `a.`, `a/`, `a;` and US-layout shifted variants such as `a>`.
- Preserve Chinese selection using Space or top-row 1–9, two-code lowercase Quick rules and Shift+number predictive selection. One-code Chinese should be selected before punctuation.
- Preserve application Shift+Tab navigation instead of appending an unintended space to pending English in the processor.
- Windows preview accepted 8 targeted checks (six punctuation / English / Chinese outputs plus `你們` from normal Quick and prediction). GitHub CI includes Lua mocked-Rime regression tests. Other keyboards, applications and Windows event paths are not exhaustively verified.

## v1.0.0 — 2026-10-31

First public baseline, released from the Windows-accepted **QuickBridge v2.9** experimental build.

- NumPad digit, arithmetic and decimal handling after 1+ Latin letters.
- Left Shift tap to confirm one or more Latin characters.
- Quick top-row 1–9 selection preserved.
- Multi-page Chinese associated phrases with Shift+number selection.
- Punctuation dismisses stale association menu.
- Safe isolated Weasel scheme and pinned-source data installer.
- No original Microsoft dictionary exports or binaries included.

Internal v2.x numbers were iterative experiments; this public project starts at **v1.0.0**.
