# Third-party attribution and data licenses

This project is **not affiliated with Microsoft, OpenVanilla, Rime, or Kinfx**.

| Component | Upstream | Distribution model / license |
| --- | --- | --- |
| Quick character dictionary (`qb_quick.dict.yaml`) | [philipposkhos/rime-ms-quick](https://github.com/philipposkhos/rime-ms-quick) | Adapted from `ms_quick.dict.yaml`, MIT license. See `licenses/RIME_MS_QUICK_LICENSE.txt`. Original upstream copyright (c) 2026 philipposkhos (Kho). |
| OpenVanilla associated phrases | [hoho97/openvanilla-kai](https://github.com/hoho97/openvanilla-kai), `DataTables/associated-phrases.cin` | Not bundled in this repo. Installer downloads a specific pinned revision as *data* and checks its exact Git blob. Source provenance and rights in the data are **not independently established**; please review upstream licensing if redistributing any generated table. |
| Third-party Traditional Chinese prediction DB | [kenspc/rime-predict-zh](https://github.com/kenspc/rime-predict-zh), `dist/predict-zht.db` | Not bundled. Installer downloads on opt-in. Upstream repository states GPL-3.0; comply with GPL-3.0 when redistributing this database. |
| Rime / Weasel (required externally) | [rime/weasel](https://github.com/rime/weasel) | Separately installed input method host and engine; **not** included here. |
| KINFX design inspiration | [Kinfxhk/kinfx-ime](https://github.com/Kinfxhk/kinfx-ime) | Independent source design reference for Shift-tap and input boundaries, **not** bundled or copied. |

Own code in `lua/`, `tools/`, and the public schema is offered under the project MIT license, except for third-party dictionary data and any expressly noted upstream licensing terms. The base dictionary retains its separately attributed MIT license.

**No official Microsoft Windows 11 dictionary or IME binaries are shipped.**
