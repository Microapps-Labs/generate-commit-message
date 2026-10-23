# gcm

Generate a Git commit message from staged changes. Preview it with `--dry-run`,
edit it with `-n`, or let `gcm` create the commit.

On supported macOS systems, the program tries Apple's Foundation Models first.
Otherwise it uses an OpenAI-compatible HTTP endpoint, with OpenRouter as the
default. API mode sends change context to the configured provider.

## Build and install

You need Git and Swift 5.9 or later. The Apple backend also requires an SDK that
includes Foundation Models and a system where that model is available.

```sh
git clone https://github.com/Microapps-Labs/generate-commit-message.git
cd generate-commit-message
make install
```

The Makefile installs `gcm` into `~/bin`. Add that directory to your `PATH`, or
set `PREFIX` when installing. To build without installing:

```sh
swift build -c release
.build/release/gcm --help
```

The package declares macOS 13 as its deployment target. The source includes a
Linux/API path, but Linux build and runtime compatibility have not been verified
yet.

## Try it

Run this inside a Git repository with changes you want to commit:

```sh
git add path/to/file
gcm --dry-run
```

Review the generated message before running `gcm` to create a commit. The
commands have different effects:

| Command | Result |
| --- | --- |
| `gcm --dry-run` | Print the message without editing or committing |
| `gcm -n` | Open the message in `$EDITOR`, then print it without committing |
| `gcm` | Generate the message and run `git commit -m` |
| `gcm -v` | Include diagnostic output |

## API configuration

Set these variables when using the HTTP backend:

```sh
export GCM_API_KEY='your-provider-key'
# Optional: replace the default OpenRouter endpoint and model.
export GCM_API_URL='https://your-provider.example/v1/chat/completions'
export GCM_MODEL='your-model-id'
```

`GCM_API_URL` is the full chat-completions URL. Keep API keys out of version
control. `--dry-run` still calls the selected model; it only prevents a Git commit.

## Message style

Create the configuration file with:

```sh
gcm --init-config
```

Edit `~/.config/gcm/config.json` to choose a conventional, simple or gitmoji
message style, length limits and custom instructions. See
[the configuration type](Sources/gcm/Config/Configuration.swift) for the current
options and defaults. The implementation reads branch names, recent commit
messages and file changes as context, and can refine messages after validation.

## Status

This is a source-built tool. A successful build and a real generation capture
are still needed before this README can demonstrate the full workflow.

## License

[MIT](LICENSE).
