# Glitch Engine — Build Process Documentation

**Phase 1 | Task 3**
Documented: 2026-05-29
Machine: Jon's MacBook Air (Apple Silicon — ARM64)
Engine Base: Godot 4.6.3-stable (custom_build [35e80b3a8])

---

## Build Result

| Item | Result |
|------|--------|
| Build status | ✅ SUCCESS |
| Build time | 7 minutes 48 seconds |
| Binary | `godot-source/bin/godot.macos.editor.arm64` |
| Version string | `v4.6.3.stable.custom_build [35e80b3a8]` |
| Editor launches | ✅ CONFIRMED |

---

## System Requirements (Verified)

| Dependency | Version | Notes |
|-----------|---------|-------|
| macOS | ARM64 (Apple Silicon) | M-series Mac |
| Xcode Command Line Tools | Installed | Path: `/Library/Developer/CommandLineTools` |
| Python | 3.9.6 | Bundled with macOS via Xcode CLT |
| SCons | 4.10.1 | Installed via `pip3 install scons --user` |
| Vulkan SDK (LunarG) | 1.4.350.0 | Installed to `~/VulkanSDK/1.4.350.0` |

---

## Build Steps

### Step 1 — Install SCons

SCons is the build system Godot uses. Python 3.9 does not support `--break-system-packages`, so install with `--user`:

```bash
pip3 install scons --user
export PATH="$HOME/Library/Python/3.9/bin:$PATH"
```

Verify:
```bash
scons --version
```

### Step 2 — Install Vulkan SDK

Godot 4 requires MoltenVK (Vulkan on macOS).

1. Download from: https://vulkan.lunarg.com/sdk/home#mac
2. Install the `.dmg` — installs to `~/VulkanSDK/<version>/`
3. Verified version: `1.4.350.0`

### Step 3 — Run the Build

```bash
export PATH="$HOME/Library/Python/3.9/bin:$PATH"
cd "/Volumes/Lito's Hard Drive/Murphree Enterprises/Glitch-Engine/godot-source"

scons platform=macos target=editor arch=arm64 \
  vulkan_sdk_path="$HOME/VulkanSDK/1.4.350.0" \
  -j$(sysctl -n hw.logicalcpu) \
  2>&1 | tee "/Volumes/Lito's Hard Drive/Murphree Enterprises/Glitch-Engine/glitch_build_log.txt"
```

**Parameters explained:**
- `platform=macos` — target platform
- `target=editor` — builds the editor (not just the runtime)
- `arch=arm64` — Apple Silicon. Change to `x86_64` for Intel Mac
- `vulkan_sdk_path` — required for Vulkan/MoltenVK on macOS
- `-j$(sysctl -n hw.logicalcpu)` — uses all CPU cores for parallel compilation
- `tee` — saves full build log to file

### Step 4 — Verify

```bash
ls -lh "/Volumes/Lito's Hard Drive/Murphree Enterprises/Glitch-Engine/godot-source/bin/"
"/Volumes/Lito's Hard Drive/Murphree Enterprises/Glitch-Engine/godot-source/bin/godot.macos.editor.arm64" &
```

Editor opens to Godot Project Manager. Bottom right shows:
`v4.6.3.stable.custom_build [35e80b3a8]`

---

## Errors Encountered & Fixed

| Error | Cause | Fix |
|-------|-------|-----|
| `no such option: --break-system-packages` | Python 3.9 doesn't support that flag | Used `pip3 install scons --user` instead |
| `MoltenVK SDK installation directory not found` | Vulkan SDK not installed | Downloaded LunarG Vulkan SDK 1.4.350.0 and added `vulkan_sdk_path` to build command |

---

## Rebuilding in the Future

To rebuild after making source changes:

```bash
export PATH="$HOME/Library/Python/3.9/bin:$PATH"
cd "/Volumes/Lito's Hard Drive/Murphree Enterprises/Glitch-Engine/godot-source"
scons platform=macos target=editor arch=arm64 vulkan_sdk_path="$HOME/VulkanSDK/1.4.350.0" -j$(sysctl -n hw.logicalcpu)
```

SCons is incremental — it only recompiles files that changed. Full rebuilds take ~8 minutes; incremental builds are much faster.

---

## Notes

- The binary is named `godot.macos.editor.arm64` — this is expected at Phase 1. Rebranding to `glitch_engine` happens in a later phase.
- The editor shows "GODOT" branding — rebranding (name, logo, splash screen) is a later phase per the roadmap.
- Build log is saved to: `/Volumes/Lito's Hard Drive/Murphree Enterprises/Glitch-Engine/glitch_build_log.txt`
- `godot-source/` is gitignored and stays local only. The build output is also local only.

---

*Glitch Engine — built by Jon, powered by Godot & Claude AI*
