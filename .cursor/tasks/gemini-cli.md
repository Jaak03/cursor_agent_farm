**Title:** Adapt Repository for Gemini CLI

**Description:** This task involves migrating the repository from using the Claude Code CLI to the Gemini CLI. This includes updating scripts, configurations, and documentation.

**Requirements:**

*   All references to `claude_code_agent_farm.py` must be replaced with a new `gemini_code_agent_farm.py`.
*   The `view_agents.sh` script needs to be updated to work with the Gemini CLI.
*   Configuration files in `configs/` might need adjustments.
*   Prompts in `prompts/` might need to be updated for Gemini.
*   The `README.md` file should be updated to reflect the change.

**Acceptance Criteria:**

*   The repository is fully functional with the Gemini CLI.
*   All scripts run without errors.
*   The `README.md` is updated and accurate.
*   All mentions of the old CLI are removed.

**Progress so far:**

*   Renamed `claude_code_agent_farm.py` to `gemini_code_agent_farm.py`.
*   Updated `view_agents.sh` to be generic.
*   Updated `README.md` to replace all instances of "Claude" and "cc" with "Gemini" and "gg".
*   Updated `pyproject.toml` to reflect the new script name.
*   Updated `setup.sh` to reflect the new script name and branding.
*   Started updating the `configs` directory.