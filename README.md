# gcm

AI-powered git commit messages. Stop staring at blank commit prompts.

```bash
$ git add .
$ gcm
✓ Committed with message:
feat(auth): add JWT token refresh mechanism
```

## What it does

`gcm` analyzes your staged changes and generates meaningful commit messages using AI:

- **macOS 26+**: Uses Apple's on-device Foundation Models (free, private, works offline)
- **Linux/older macOS**: Uses OpenRouter or OpenAI-compatible APIs

## Install

```bash
# Build from source
swift build -c release
cp .build/release/gcm /usr/local/bin/

# Or with Nix
nix build
nix profile install .
```

## Usage

```bash
gcm              # Generate and commit
gcm -n           # Generate, edit in $EDITOR, don't auto-commit
gcm --dry-run    # Preview only
gcm -v           # Verbose mode
```

## Configuration

```bash
gcm --init-config  # Creates ~/.config/gcm/config.json
```

```json
{
  "commitStyle": "conventional",
  "conventionalTypes": ["feat", "fix", "docs", "chore", "refactor", "test", "perf"],
  "scopeRequired": false,
  "maxLength": 72,
  "includeBody": true,
  "customInstructions": "Reference JIRA tickets when mentioned in branch names"
}
```

### Commit Styles

- `conventional` — `feat(scope): description` (default)
- `simple` — Plain descriptive messages
- `gitmoji` — `✨ Add new feature`

## Environment Variables

For Linux or older macOS (when Apple Intelligence isn't available):

```bash
export GCM_API_KEY="your-api-key"           # Required
export GCM_API_URL="https://..."            # Optional, defaults to OpenRouter
export GCM_MODEL="anthropic/claude-3.5-sonnet"  # Optional
```

## Smart Features

- **Branch inference**: `feature/auth` → `feat(auth):`, `fix/login-bug` → `fix(login):`
- **Style matching**: Analyzes recent commits to match your repo's style
- **Context-aware**: Considers staged diff, file changes, and branch name

## Requirements

- macOS 13+ or Linux
- Swift 5.9+
- For Apple Intelligence: macOS 26+ with Apple Silicon

## License

MIT
