# 速橋 QuickBridge IME

**v1.0.1** · Windows 11 · [Rime 小狼毫 / Weasel](https://github.com/rime/weasel) · Free and open source

A compact Traditional Chinese **Quick (速成)** input method with no-mode-switch English typing, NumPad digits, and Chinese next-character suggestions. Based on a Windows-validated v2.9 personal prototype, re-released as the **first public release v1.0.0**.

> **Not a Microsoft product.** This project does not contain or claim a Microsoft Windows 11 IME dictionary export. The association list is from historical third-party OpenVanilla data.

## Features

- Quick character selections on the **top-row 1–9 keys**, with 9 candidates per page and Space for paging.
- **NumPad numbers always type numbers**, even immediately after one or two alphabetic letters (`h` + NumPad 1 → `h1`).
- **Tap Left Shift** to confirm raw English without adding a space (`h` → `h`, `of` → `of`); Shift+Space also confirms with a space.
- Longer inline English and numbers (`hello123`, `hi+` via NumPad Plus).
- **Shift + top-row 1–9** to select next-character suggestions; Space pages association suggestions.
- Punctuation after Chinese cancels the association menu, rather than accidentally picking another Chinese character.
- The base Quick code table is derived from Kho's MIT-licensed Rime dictionary. Historical association data contain **44,572 entries / 4,017 leading characters**, downloaded separately on installation.

## Unreleased v1.0.2 candidate — Windows QA pending

- Fix **two-letter lowercase English + punctuation** (for example `wo.`, `of,`, `hi?`, `vd;`) without switching input modes.
- Consecutive physical punctuation stays literal after an English boundary: `wo...`, `wo+...`, and `hello...` (not just the first dot). The next letter starts a fresh Quick code.
- **Compatibility change:** After either one or two Latin letters, punctuation is treated as English. If you want Chinese, select the Chinese candidate with top-row 1–9 (or the existing Space behavior) **before** punctuation. Numeric selection and Shift+number Chinese prediction remain unchanged.
- Windows real-world verification of this new candidate is still required. The current published release remains v1.0.1.

## What's new in v1.0.1

- After a single Latin letter, main-keyboard punctuation now commits literal English (`a,`, `a.`, `a/`, `a;`, and US-layout Shift variants such as `a>`).
- One-code Chinese characters must be selected **before** punctuation (for example, `f` + Space → `火`); two-code Quick candidate selection remains native.
- Shift+Tab with pending English no longer commits an unwanted trailing space in the processor. Windows focus behavior may still vary by application.
- Existing v1.0.0 users can retain their existing setup until they deliberately upgrade. No input-method or Windows configuration is changed by a GitHub release.

## Already using QuickBridge v2.9 on Windows? (No reinstall)

The public `v1.0.0` release is **exactly the v2.9 keyboard processor**, with a clean release label. To keep the working installation and add just the new name:

```powershell
.\Promote-v29-to-v1.ps1 -Mode Check
.\Promote-v29-to-v1.ps1 -Mode Stage
```

Run this from the source ZIP's `tools` directory. Enter `QB-PROMOTE-1` when prompted. It creates only **`quickbridge.schema.yaml`** under your Rime user directory; no code, dictionary or current scheme is replaced. Enable **速橋 QuickBridge** in Weasel Input Method Settings and redeploy.

**This path is recommended for existing v2.9 users.** The full installer below is primarily for a new computer.

## Windows setup

1. Install the official [Rime Weasel](https://github.com/rime/weasel/releases), preferably 0.17.4 or newer with `librime-predict` support. This project does **not** install Weasel for you.
2. Download the public source/release ZIP and extract it to a normal folder.
3. Run **PowerShell as your ordinary Windows user**, not Administrator, from the extracted `tools` directory:

   ```powershell
   .\Install-QuickBridge.ps1 -Mode Check
   .\Install-QuickBridge.ps1 -Mode Install
   ```

4. Type `QB-INSTALL-1` when prompted. Installation fetches two **pinned third-party data files** over HTTPS, validates their Git blob hashes, verifies **51 tested Chinese heads / 442 positions**, then installs under `%APPDATA%\Rime`.
5. Open **Weasel Input Method Settings (小狼毫輸入法設定)** and select **速橋 QuickBridge**. Then **Redeploy (重新部署)** and select the new scheme. Keep your existing input methods enabled.

This script **does not** modify `default.custom.yaml`, `weasel.custom.yaml`, Windows Registry, Microsoft IME, or other schemes. It refuses to overwrite different existing files. `-Mode Check` is offline and read-only. The installer requires the predictive Rime module already available in supported Weasel builds.

### Common key examples

| Keys | Expected text |
| --- | --- |
| `h` + top-row `1` | `竹` |
| `h` + NumPad `1` | `h1` |
| `h` + tap **Left Shift** | `h` |
| `of` + top-row `2` | `你` |
| `of` + top-row `2` + Shift+top-row `1` | `你們` |
| `hi` + NumPad `+` | `hi+` |
| `hello` + NumPad `1`, `2`, `3` | `hello123` |
| `vd` + top-row `1` + Space + Shift+top-row `1` | `好意思` |
| `of` + top-row `2` + `,` | `你,` (suggestions dismissed) |

The top-row number keys and the numeric keypad intentionally behave differently. With NumLock off, keypad navigation remains navigation.

## Versioning and testing

- **Current public release**: `v1.0.1`, based on the Windows-accepted v2.9 / v1.0.0 baseline. Internal Lua filenames retain historical module suffixes and do not indicate public version.
- Personal Windows acceptance covered baseline `h1h`, `hi+`, `hello123`, `你們`, and targeted v1.0.1 preview results `a.`, `a/`, `a;`, `a>`, `of` (left Shift), `火` (Space), and `你們` (Quick + prediction). Other scenarios were tested in Lua 5.4 with mocked Rime context. These tests **do not prove every Windows app or keyboard layout works**.
- The source ships Lua simulation tests in `tests/`. Run with Lua 5.4 when available. For future CI, see [CONTRIBUTING.md](CONTRIBUTING.md).
- Windows may deliver modifier release events differently in Remote Desktop, custom keyboard layouts, or other IME clients. Left Shift behavior may vary.

## Requirements / limits

- Windows 11 and recent Weasel/Rime with Lua and predict components.
- Network access on first install to download the two pinned datasets. If the upstream content moves or changes, install fails **safely**, rather than silently trusting unverified replacement data.
- The OpenVanilla lexicon matched 442/442 observed **first-page** positions. This is not verification of the whole Windows 11 native ordering.
- Currently Windows-focused. No native macOS/Linux validation.

## License and attribution

Original QuickBridge glue code: **MIT**. The included adapted Quick character table is MIT under its upstream author's license. Downloaded data have **their own separate provenance/licensing**; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). **Do not assume every downloaded dictionary is MIT.**

Bug reports and contributions are welcome; please include Windows, Weasel version, NumLock state, and an exact key sequence, but **never paste credentials, private typed text, or personal data**.
