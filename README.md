# CAFShared

Source folders shared by the CAF apps: **Cashier** (`com.itcaf.biz`, `../Cashier`) and **CAF BiO** (`com.itcaf.cafbio`, `../CAF-user`).
It is not a Swift package: each app's `project.yml` lists the folders it needs as XcodeGen source paths (`../CAFShared/CAFKit/Core`, …), so the code is compiled into the app and nothing needs `public`. Clone it next to the apps.

## Folders
| Folder | What | Cashier | Cashier Clip | CAF BiO | BiO Clip / widgets |
|---|---|:-:|:-:|:-:|:-:|
| `CAFKit/Core` | AppConfig, Keychain, L10n/LanguageManager, Haptics, Reachability, Decoding+Flex | yes | yes | yes | as needed |
| `CAFKit/Cashier` | cashier session, store, models, offline queue, drive board, `HTTPTransport` | yes | yes | yes (branch view) | no |
| `CAFKit/Owner` | owner session, store, models | no | no | yes | no |
| `CAFKit/Push` | `PushRegistrar`, `PushAppDelegate`, `DeviceRegistering`, `NotificationCategories` | yes | no | yes | no |
| `CAFKit/Realtime` | `RealtimeClient`, `PollingRealtimeClient` | yes | yes | yes | no |
| `CAFKit/Pager` | `PagerActivityAttributes` (Live Activity) | no | no | Clip + its widget | yes |
| `CAFDesign` | tokens, brand shapes, components | yes | yes | yes | as needed |
| `Resources/Fonts` | fonts (an App Clip lists a lean subset with `includes`) | yes | subset | yes | subset |
| `Strings/strings_*.py` | string tables for keys used by shared code | merged by every app's `scripts/gen_strings.py` | | | |
| `_handoff/` | one-off hand-over of the owner screens/tests/strings moved out of Cashier | | | pick up, then delete | |

## Contract
1. **No app names in shared code.** Per-app values come from Info.plist through `AppConfig`: `CAFKeychainService`, `CAFClipKeychainService`, `CAFAppGroup`, `CAFURLScheme`, `CAFLinkHosts` (comma list). Missing keys fall back to the cashier app's values (`com.itcaf.biz`). Each app sets all five in `project.yml`.
2. **Per-target behaviour = compile conditions** (`#if APPCLIP`, `#if DEBUG`), never by importing app types. Shared files may use only `CAFKit`/`CAFDesign` symbols and system frameworks.
3. **Strings**: shared code calls `L10n.string("key")` / `Text("key")`. Keys it needs are defined in `Strings/strings_*.py` (UPPER_CASE dicts of `key: (ar, en)`); `CAFDesign` also expects `app.name` from the app. Apps merge `../CAFShared/Strings/strings_*.py` in `gen_strings.py` and own the generated catalog.
4. **Wire contracts that must not drift**: notification category ids `CASHIER_ORDER` (actions `prepare`, `ready`), `OWNER_BRANCH` (`pause`, `open`), `PAGER_READY` (`picked`); `PagerActivityAttributes.ContentState` property names (`stage`, `title`, `subtitle`, `eta`, `progress`, `order_number`, `product_title`) are the server's JSON keys (`cafbio-clips/src/Devices.php` contentState()); stages 2 preparing, 6 ready, 3 picked, 4 cancelled.
5. **Push**: the app creates `@UIApplicationDelegateAdaptor(PushAppDelegate.self)`, calls `PushRegistrar.shared.requestAuthorization()` at a sensible moment, and sets `PushRegistrar.shared.registering = <its DeviceRegistering>` after sign-in (the token is posted at once if already known) and `unregister()` on sign-out. `onSilentPush` should call `PollingRealtimeClient.onSilentPush()`; `onTap` hands a `NotificationTap` to the app's single deep-link router.
6. **Realtime**: `RealtimeClient.events(since:)` returns bus rows (`RealtimeEvent`, snake_case via `JSONDecoder.api`); `PollingRealtimeClient` polls a closure with exponential backoff and wakes immediately on a silent push.
7. Changing a shared file means building every app that includes it.
