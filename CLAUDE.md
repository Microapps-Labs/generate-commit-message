# CLAUDE.md

## Project Overview

`gcm` is a Swift CLI tool that generates git commit messages using AI. It's cross-platform with a hybrid backend strategy.

## Architecture

```
Sources/gcm/
├── Commands/GCMCommand.swift    # Entry point, ArgumentParser
├── Config/                      # JSON config at ~/.config/gcm/
├── Git/                         # GitAnalyzer, ShellExecutor
├── AI/                          # AIBackend protocol + implementations
└── Editor/                      # $EDITOR integration
```

### AI Backend Selection

The `AIBackendFactory` auto-selects:
1. **AppleAIBackend** — Uses `FoundationModels` framework (macOS 26+, on-device)
2. **OpenRouterBackend** — Falls back to HTTP API when Apple Intelligence unavailable

Conditional compilation via `#if canImport(FoundationModels)` ensures Linux builds exclude Apple-specific code.

## Build Commands

```bash
swift build                 # Debug build
swift build -c release      # Release build
swift test                  # Run tests
swift run gcm --help        # Run directly
```

## Key Files

- `Package.swift` — Single dependency: swift-argument-parser
- `AIBackend.swift` — Protocol + factory for backend selection
- `PromptBuilder.swift` — Constructs prompts from git context
- `GitAnalyzer.swift` — Concurrent git command execution

## Config Location

`~/.config/gcm/config.json` — JSON format, Codable struct in `Configuration.swift`

## Environment Variables

- `GCM_API_KEY` — API key for OpenRouter/OpenAI
- `GCM_API_URL` — Override API endpoint
- `GCM_MODEL` — Override model selection

## Testing Locally

```bash
# With Apple Intelligence (macOS 26+)
git add . && swift run gcm --dry-run

# With API (set key first)
export GCM_API_KEY="sk-..."
git add . && swift run gcm --dry-run
```

## Nix

`flake.nix` provides cross-platform builds. Run `nix build` or `nix run`.
