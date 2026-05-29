# Glitch Engine — Changelog

---

## Phase 1 — Engine Foundation ✅ [Complete — 2026-05-29]

### Added
- Repository initialized
- Complete folder structure per project spec
- README.md
- CHANGELOG.md
- ROADMAP.md
- PROJECT_STATUS.md
- BUILD_PROCESS.md (macOS ARM64 build steps, dependencies, errors & fixes)
- LICENSES/GODOT_LICENSE.md
- LICENSES/GLITCH_ENGINE_LICENSE.md
- LICENSES/THIRD_PARTY_LICENSES.md
- tasks/phase_01_setup.md through tasks/phase_16_release.md
- .gitignore (godot-source excluded)
- Godot 4.6.3-stable cloned locally to godot-source/
- Godot 4.6.3-stable built successfully (binary: godot.macos.editor.arm64)
- Editor launch confirmed

---

## Phase 2 — Rebrand ✅ [Complete — 2026-05-29]

### Changed
- `version.py`: `name` → "Glitch Engine", `short_name` → "glitch_engine", `website` → "https://glitchengine.dev"
- `editor/settings/editor_settings.cpp`: default theme preset → "Glitch Engine" (dark near-black base, neon purple accent)
- `editor/themes/editor_theme_manager.cpp`: added "Glitch Engine" preset (base #17171E, accent #A633FF, icon saturation 1.5)
- `editor/gui/editor_about.cpp`: About dialog title updated to "Glitch Engine community"
- `editor/project_manager/project_manager.cpp`: translator comment updated

### Added
- `main/splash.png`: Glitch Engine branded splash (800×450, dark bg, neon purple, scanline effect, ⚡ logo)

### Preserved
- All Godot MIT copyright notices in source files (legal requirement)
- LICENSES/ directory unchanged

---

*Format: Phase — Date*
*Change types: Added / Changed / Fixed / Removed*
