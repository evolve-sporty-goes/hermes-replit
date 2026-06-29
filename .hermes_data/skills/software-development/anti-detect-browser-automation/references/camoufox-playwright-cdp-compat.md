# isMobile CDP Protocol Incompatibility — Version History

## 2025-06-29 (current session)

- Camoufox v135.0.1-beta.24, cloverlabs-camoufox (PyPI)
- Playwright version at time of breakage: post-1.50 (exact version not pinned, reinstalled via pip)
- The `doUpdateDefaultViewport` method in coreBundle.js constructs the viewport object ~line 44997
- Offending line confirmed at line 45004: `          isMobile: !!this._options.isMobile`
- Fix applied: `sed -i '/          isMobile: !!this._options.isMobile/d' "$JS_FILE"`
- `deviceScaleFactor` line remains (it's valid in Firefox CDP schema)
- "Skipping unknown patch audio:seed" / "Skipping unknown patch canvas:seed" confirmed harmless

## Earlier (skill v1.0)

- Same root cause, but original context/line numbers differed (the sed pattern used `deviceScaleFactor ... || 1,\\n isMobile` as a combined match — this no longer matches because modern Playwright formats the object differently, with comma already present after `deviceScaleFactor`).
