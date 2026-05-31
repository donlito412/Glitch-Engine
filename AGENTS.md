## Imported Claude Cowork project instructions
## Glitch Engine - Universal Agent Workflow Rules

ALL AI agents working on the Glitch Engine project MUST adhere to the following workflow rules exactly:

1. **Bash Scripts to Outputs Folder**: All code changes or file creations must be provided as a Bash script that writes the files to disk. The script must be saved in an `outputs` directory inside the project root.
2. **Visible Execution**: Do NOT run commands quietly or pipe output to the clipboard (no `| pbcopy`). Provide the raw shell command (e.g., `sh outputs/script.sh`) so the user can run it and see all terminal output for debugging.
3. **Complete File Rewrites Only**: When modifying files via bash scripts, write the entire contents of the file. Do not use sed or partial edits in the script.
4. **Sync Both Plugin Locations**: Glitch Engine has two locations for its plugins. Whenever an AI plugin file is modified, the change MUST be written to BOTH locations simultaneously to keep them perfectly synced:
   - Location A (Source): `glitch-engine/plugins/glitch_ai_assistant/`
   - Location B (Live Test Project): `glitch-engine/sample_projects/glitch_ai_test/addons/glitch_ai_assistant/`
5. **Always Push to GitHub**: Every bash script that makes changes must conclude by staging the files (`git add .`), committing them with a descriptive message (`git commit -m "..."`), and pushing them to the remote repository (`git push`).
6. **Absolute Navigation**: All bash scripts MUST start by navigating to the project root (`cd "/Volumes/Lito's Hard Drive/Murphree Enterprises/Glitch-Engine" || exit`) to ensure they execute correctly regardless of where the user's terminal is located.
7. **Godot Cache Restart**: Whenever a Godot script (`.gd`) is modified, the bash script MUST include commands to safely kill and relaunch the custom source-built Godot binary (`pkill -f "godot.macos.editor" 2>/dev/null; sleep 1; "/Volumes/Lito's Hard Drive/Murphree Enterprises/Glitch-Engine/godot-source/bin/godot.macos.editor.arm64" --editor "glitch-engine/sample_projects/glitch_ai_test/project.godot" &`) so the editor's in-memory cache is fully cleared.

If you are an AI agent reading this, do not deviate from these core workflow rules under any circumstances.
