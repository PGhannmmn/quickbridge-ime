# Contributing

This is a small, Windows-focused Rime input method project. Please keep changes narrow and backward-compatible.

- Preserve top-row `1–9` for Quick selection; NumPad digits stay literal.
- Preserve Left Shift tap, Shift+number associations, and Space paging.
- Avoid global configuration changes, registry edits and implicit deletion.
- Add a Lua test for each new keyboard-boundary rule and document any Windows real-world result separately from mocked test results.
- Do not commit downloaded prediction database files, reconstructed OpenVanilla data, local `%APPDATA%/Rime` files, user dictionaries, secrets, or personal keystroke logs.

Open an Issue with the exact keyboard event sequence, NumLock state and Weasel version; use disposable text, not private content.
