# Yank — every command this project needs.
#
#   make            list the targets
#   make run        build and launch
#   make test       run the test suite
#
# Everything here shells out to swift, build.sh or the Tools scripts; nothing
# is duplicated. See CLAUDE.md for why the project has no .xcodeproj.

SHELL     := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

APP       := build/Yank.app
BINARY    := $(APP)/Contents/MacOS/Yank
BUNDLE_ID := dev.ramacharan.yank
INSTALLED := /Applications/Yank.app
HISTORY   := $(HOME)/Library/Application Support/Yank/history.json

.DEFAULT_GOAL := help

# ─────────────────────────────────────────────────────────────────── Build

## build: compile and assemble the debug .app
build:
	@./build.sh

## release: compile and assemble the optimised .app
release:
	@./build.sh release

## run: build release, then launch (replaces a running copy)
run: release stop
	@open $(APP)
	@echo "==> Running. The icon is in the menu bar."

## debug-run: run in this terminal so print() and os_log land on stdout
debug-run: build stop
	@echo "==> Ctrl-C to stop"
	@$(BINARY)

## stop: quit a running copy and wait for it to actually exit
stop:
	@pkill -x Yank 2>/dev/null || true
	@until ! pgrep -qx Yank; do :; done

# ──────────────────────────────────────────────────────────────────── Test

## test: run the full test suite
test:
	@swift test

## test-filter: run one suite or test, e.g. make test-filter FILTER=ClipStore
test-filter:
	@test -n "$(FILTER)" || { echo "usage: make test-filter FILTER=<name>" >&2; exit 2; }
	@swift test --filter "$(FILTER)"

## check: the gate before committing — warning-free release build plus tests
check:
	@echo "==> Building release"
	@if swift build -c release 2>&1 \
		| grep -E 'warning:' \
		| grep -vE 'ld: warning|search path' \
		| grep -E '$(CURDIR)/(Sources|Tests)|Yank\.[A-Za-z]+'; then \
		echo "FAIL: warnings in our own code" >&2; exit 1; \
	fi
	@echo "==> Building tests"
	@if swift build --build-tests 2>&1 \
		| grep -E 'warning:' \
		| grep -vE 'ld: warning|search path' \
		| grep -E '$(CURDIR)/(Sources|Tests)|Yank\.[A-Za-z]+'; then \
		echo "FAIL: warnings in test code" >&2; exit 1; \
	fi
	@echo "==> Testing"
	@swift test
	@echo "==> Clean: no warnings, all tests passing"

# ─────────────────────────────────────────────────────────────────── Icons

## icons: redraw the app icon and menu bar glyph from Tools/IconGen.swift
icons:
	@swift Tools/IconGen.swift Resources >/dev/null
	@iconutil -c icns Resources/Yank.iconset -o Resources/Yank.icns
	@echo "==> Resources/Yank.icns"

## preview: render Resources/preview.png for reviewing an icon change
preview: icons
	@swift Tools/IconPreview.swift Resources >/dev/null
	@echo "==> Resources/preview.png"
	@open Resources/preview.png

# ───────────────────────────────────────────────────────────────── Install

## install: copy the release build into /Applications
install: release stop
	@rm -rf "$(INSTALLED)"
	@cp -R $(APP) /Applications/
	@echo "==> $(INSTALLED)"
	@echo "    Open it, then turn on Launch at login in Settings."

## uninstall: remove the installed app (history and preferences are kept)
uninstall:
	@rm -rf "$(INSTALLED)"
	@echo "==> Removed $(INSTALLED). Run 'make purge' to drop saved data too."

# ─────────────────────────────────────────────────────────────────── Clean

## clean: remove build products and generated icons
clean:
	@rm -rf .build build Resources
	@echo "==> Removed .build, build, Resources"

## purge: DESTRUCTIVE — also delete saved clipboard history and preferences
purge: clean
	@rm -f "$(HISTORY)"
	@defaults delete $(BUNDLE_ID) 2>/dev/null || true
	@echo "==> Deleted saved history and preferences"

# ──────────────────────────────────────────────────────────────────── Info

## where: show where things live on disk
where:
	@echo "  app        $(APP)"
	@echo "  installed  $(INSTALLED)"
	@echo "  history    $(HISTORY)"
	@echo "  icons      Resources/ (generated; source is Tools/IconGen.swift)"

## help: list these targets
help:
	@echo "Yank — available targets:"
	@echo
	@grep -E '^## ' $(MAKEFILE_LIST) \
		| sed 's/^## //' \
		| awk -F': ' '{ printf "  \033[1m%-14s\033[0m %s\n", $$1, $$2 }'
	@echo
	@echo "  Pass VERSION=x.y to release/install to stamp a version."

.PHONY: build release run debug-run stop test test-filter check icons preview \
        install uninstall clean purge where help
