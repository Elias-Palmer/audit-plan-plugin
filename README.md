# audit-plan-plugin

A Claude Code plugin that automatically audits plans before they're presented to you.

When Claude tries to exit plan mode, this plugin intercepts the exit and forces Claude to critically review its own plan for mistakes, missing steps, and gaps. After the audit pass, Claude exits plan mode normally. One pass, no infinite loops.

## Why

Manually asking Claude to "audit your plan" consistently catches real errors — missing edge cases, wrong file paths, logical gaps, skipped verification steps. This plugin automates that prompt so you never forget to ask.

## How It Works

1. You enter plan mode and give Claude a task
2. Claude writes a plan and calls `ExitPlanMode`
3. The plugin **denies** the exit and injects an audit prompt
4. Claude reviews its own plan, fixes issues, and updates the plan file
5. Claude calls `ExitPlanMode` again — this time it's **allowed through**

```
ExitPlanMode (1st call)
    → Hook denies exit
    → Claude audits and updates plan
ExitPlanMode (2nd call)
    → Hook allows exit
    → Plan presented to user
```

### Dual-hook design

The plugin uses two hooks for reliability:

- **Primary** (`PreToolUse` on `ExitPlanMode`) — intercepts the tool call directly
- **Fallback** (`Stop`) — catches plan exits if `ExitPlanMode` isn't hookable via `PreToolUse`

Only one fires per plan. State files in `/tmp` coordinate between them and are cleaned up on session end.

## Installation

### Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- `jq` (JSON processor)

### Install via marketplace

```bash
# Clone the repo
git clone git@github.com:Elias-Palmer/audit-plan-plugin.git

# Add the local marketplace
claude plugin marketplace add ./audit-plan-plugin

# Install the plugin (user scope — applies to all projects)
claude plugin install audit-plan@audit-plan-marketplace
```

Or install at project scope (shared via version control):

```bash
claude plugin install audit-plan@audit-plan-marketplace --scope project
```

### Quick test (no install)

Load the plugin for a single session without installing:

```bash
claude --plugin-dir ./audit-plan-plugin
```

<details>
<summary>Managing the plugin (disable, update, uninstall, reload)</summary>

```bash
# Disable without uninstalling
claude plugin disable audit-plan@audit-plan-marketplace

# Re-enable
claude plugin enable audit-plan@audit-plan-marketplace

# Update after pulling new changes
claude plugin update audit-plan@audit-plan-marketplace

# Uninstall
claude plugin uninstall audit-plan@audit-plan-marketplace
```

If you modify the plugin while Claude Code is running, reload without restarting:

```
/reload-plugins
```

</details>

## Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| Linux | Supported | |
| macOS | Supported | |
| Windows | Not supported | Works under WSL or Git Bash, but not native `cmd`/PowerShell |

## Project Structure

```
audit-plan-plugin/
├── .claude-plugin/
│   ├── plugin.json        # Plugin manifest
│   └── marketplace.json   # Local marketplace catalog
├── hooks/
│   └── hooks.json         # Hook definitions
├── scripts/
│   ├── audit-plan.sh      # Primary hook (PreToolUse)
│   ├── audit-stop.sh      # Fallback hook (Stop)
│   └── cleanup.sh         # Session cleanup
├── LICENSE
└── README.md
```

## License

[MIT](LICENSE)
