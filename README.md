# PlanReview

A native macOS app for reviewing AI-generated implementation plans. Built for developers who use AI coding agents like Claude Code, OpenAI Codex, Gemini CLI, and OpenCode.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)
![License: MIT](https://img.shields.io/badge/License-MIT-green)

![PlanReview screenshot](docs/screenshot.png)

## Features

- **Markdown Rendering** - Beautiful rendering with syntax highlighting for code blocks
- **Inline Comments** - Add comments to any selection with `Cmd+K`
- **Multi-Tab Support** - Review multiple plans concurrently (`Cmd+1-9` to switch, `Cmd+[/]` to navigate)
- **CLI Integration** - Blocking CLI for AI agents that waits for your approval
- **Approve/Request Changes** - Clear workflow with `.done` file signaling for agent automation

## Installation

### From Source

```bash
# Clone the repository
git clone https://github.com/zeigarnick/PlanReview.git
cd PlanReview

# Build and install to /Applications
./build.sh
```

### First Launch (Gatekeeper)

Since the app is not notarized, macOS will block it on first launch. To allow it:

**Option A: System Settings**
1. Try to open Plan Review - you'll see "cannot be opened"
2. Go to **System Settings → Privacy & Security**
3. Scroll down and click **"Open Anyway"** next to Plan Review
4. Click **Open** in the confirmation dialog

**Option B: Terminal**
```bash
xattr -cr /Applications/Plan\ Review.app
open /Applications/Plan\ Review.app
```

## Usage

### Standalone

Open any markdown file:
```bash
open -a "Plan Review" path/to/plan.md
```

Or use `Cmd+O` within the app, or drag-and-drop files.

### CLI (for AI Agent Integration)

The CLI opens the plan and **blocks until you approve or request changes**:

```bash
# Add to your PATH (one-time setup)
sudo ln -sf "$(pwd)/planreview-cli" /usr/local/bin/planreview

# Use from anywhere
planreview path/to/plan.md
```

When you click **Submit** or **Request Changes** in the app:
- A `.done` file is created (e.g., `plan.done` for `plan.md`)
- The CLI unblocks and outputs the result
- If you added comments, a `.comments.json` file is also created

## AI Agent Integration

PlanReview integrates with AI coding agents. The agent writes a plan, submits it for review, blocks until you approve or request changes, and reads the result.

### How It Works

```
Agent writes plan → submits for review → BLOCKS
                                           ↓
                         You review in native macOS app
                                           ↓
                         Click "Submit" or "Request Changes"
                                           ↓
Agent receives ← tool/CLI unblocks with result ← .done file created
```

**Output files:**
- `plan.done` - Created on submit/request changes, contains result status
- `plan.comments.json` - Created if you added inline comments

### OpenCode

**Option A: Native Tool (Recommended)**

Copy the custom tool to your global OpenCode tools directory:

```bash
mkdir -p ~/.config/opencode/tools
cp .opencode/tools/submit_plan.ts ~/.config/opencode/tools/
```

Then add workflow instructions to your `AGENTS.md` or your agent's prompt:

```markdown
## Plan Review Workflow

Before implementing multi-step features, submit your plan for human review:

1. Write the plan to a markdown file
2. Call the `submit_plan` tool with the absolute file path
3. **Wait for the result** - the tool blocks until the user responds
4. If approved, proceed with implementation
5. If changes requested, read the comments in the response and revise

The submit_plan tool opens a native macOS review app. Do not timeout or cancel it.
```

**Option B: CLI via Bash**

Alternatively, use the CLI through bash permissions.

Add CLI permission in `opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "permission": {
    "bash": {
      "planreview *": "allow"
    }
  }
}
```

Add workflow instructions to your `AGENTS.md` or agent prompt:

```markdown
## Plan Review Workflow

For implementation plans, submit for human review before coding:

1. Write the plan to a markdown file
2. Run: `planreview <path-to-plan.md>`
3. Wait for the command to complete (it blocks until user responds)
4. Exit 0 = approved, Exit 1 = changes requested
5. If changes requested, read `.comments.json` and revise

The command opens a native macOS app for review. Do not timeout.
```

### Claude Code

**Step 1: Allow the command** in `.claude/settings.json`:

```json
{
  "permissions": {
    "allow": [
      "Bash(planreview *)"
    ]
  }
}
```

**Step 2: Add workflow instructions** to `CLAUDE.md` or your agent prompt:

```markdown
## Plan Review Workflow

Before implementing multi-step features, submit your plan for human review:

1. Write the plan to a markdown file
2. Run: `planreview <path-to-plan.md>`
3. **Wait for the command to complete** - it blocks until the user responds
4. Check the exit status:
   - Exit 0 = approved, proceed with implementation
   - Exit 1 = changes requested, read `<plan>.comments.json` for feedback
5. If changes requested, revise the plan and resubmit

**Important:** The planreview command blocks until the user clicks Submit or Request Changes in the app. Do not timeout or cancel it.
```

### OpenAI Codex CLI

Add workflow instructions to your `AGENTS.md` or agent prompt:

```markdown
## Plan Review Workflow

Before implementing any multi-step feature:

1. Write a detailed implementation plan to a markdown file
2. Run: `planreview <path-to-plan.md>`
3. **Wait for the command to complete** - it blocks until the user responds
4. If the command exits with status 1, changes were requested:
   - Read `<plan>.comments.json` for inline feedback
   - Revise the plan and resubmit
5. If the command exits with status 0, proceed with implementation

The planreview command opens a native macOS review UI. Do not timeout or cancel it.
```

Codex discovers `AGENTS.md` files at:
- `~/.codex/AGENTS.md` (global)
- `<project-root>/AGENTS.md` (project)
- `<subdirectory>/AGENTS.md` (nested overrides)

### Google Gemini CLI

Add workflow instructions to your `GEMINI.md` or agent prompt:

```markdown
## Plan Review Tool

For implementation plans, use the planreview CLI:

\`\`\`bash
planreview path/to/plan.md
\`\`\`

This opens a native macOS review UI and **blocks until the user approves or requests changes**. Do not timeout or cancel the command.

- Exit 0 = approved
- Exit 1 = changes requested (read `.comments.json` for feedback)
```

You can also create a custom slash command at `~/.gemini/commands/review.toml`:

```toml
description = "Submit a plan for human review"
prompt = """
Submit the plan at {{args}} for human review.
Run: planreview {{args}}
Wait for the command to complete and read the result before proceeding.
If exit status is 1, read the .comments.json file for feedback.
"""
```

Invoke with: `/review path/to/plan.md`

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+O` | Open file |
| `Cmd+K` | Add comment to selection |
| `Cmd+/` | Toggle comments sidebar |
| `Cmd+1-9` | Switch to tab 1-9 |
| `Cmd+[` | Previous tab |
| `Cmd+]` | Next tab |
| `Cmd+Return` | Submit (approve) plan |
| `Cmd+Shift+R` | Request changes |

## Requirements

- macOS 14.0 (Sonoma) or later
- Swift 5.9+ (for building from source)

## Development

```bash
# Build debug version
swift build

# Run tests
swift test

# Build release and install
./build.sh
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and guidelines.

## License

MIT License - see [LICENSE](LICENSE) for details.
