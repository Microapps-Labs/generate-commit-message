.PHONY: build install clean run test help

PREFIX ?= $(HOME)/bin

build:
	@swift build -c release

install: build
	@mkdir -p $(PREFIX)
	@cp .build/release/gcm $(PREFIX)/gcm
	@echo "✓ Installed gcm to $(PREFIX)/gcm"

uninstall:
	@rm -f $(PREFIX)/gcm
	@echo "✓ Removed gcm from $(PREFIX)"

clean:
	@swift package clean
	@rm -rf .build
	@echo "✓ Cleaned build artifacts"

run:
	@swift run gcm

test:
	@swift test

help:
	@echo "gcm - AI-powered git commit message generator"
	@echo ""
	@echo "Usage:"
	@echo "  make build     Build release binary"
	@echo "  make install   Build and install to ~/bin (or PREFIX=path)"
	@echo "  make uninstall Remove from ~/bin"
	@echo "  make clean     Remove build artifacts"
	@echo "  make run       Run in development mode"
	@echo "  make test      Run tests"
