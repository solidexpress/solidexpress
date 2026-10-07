BUILD_DIR := build
GODOT := tools/godot/godot
JOBS := $(shell nproc)

.PHONY: all configure build test test-kernel test-godot preflight test-tools lint-rung01-e2e clean import movies publish-demo-movies sync-website check-website-demos release-linux fetch-godot-templates

VERSION := $(shell cat VERSION 2>/dev/null || echo 0.0.0-dev)

# OCCT shared libraries must be on the loader path or libsxcore does not load
# and every Godot script dies with "Could not find type SxDocument".
-include packaging/occt.version
OCCT_PREFIX ?= /opt/occt-$(OCCT_VERSION)
ifneq ($(wildcard $(OCCT_PREFIX)/lib),)
export LD_LIBRARY_PATH := $(OCCT_PREFIX)/lib$(if $(LD_LIBRARY_PATH),:$(LD_LIBRARY_PATH))
endif

all: build

configure:
	cmake -S . -B $(BUILD_DIR) -G Ninja \
		$(if $(CMAKE_PREFIX_PATH),-DCMAKE_PREFIX_PATH="$(CMAKE_PREFIX_PATH)")

build: configure
	cmake --build $(BUILD_DIR) -j $(JOBS)

test-kernel: build
	./$(BUILD_DIR)/sxkernel/sxkernel_tests
	./$(BUILD_DIR)/sxvoice/sxvoice_tests

# First import bakes .godot cache; needed once before running scripts headless.
import: build
	$(GODOT) --headless --path game --import > /dev/null 2>&1 || true

preflight: build import
	$(GODOT) --headless --path game --script tests/preflight_sxcore.gd

test-godot: build import preflight
	GODOT_BIN=$(GODOT) packaging/ci/run_suites.sh --tier full $(if $(KEEP_GOING),--keep-going)

lint-rung01-e2e:
	python3 tools/lint_rung01_e2e.py

test-tools:
	@if [ -f tools/test_check_rung01.py ]; then python3 tools/test_check_rung01.py; fi
	python3 tools/lint_suites.py

test: test-kernel
	python3 tools/lint_rung01_e2e.py
	$(MAKE) test-tools
	$(MAKE) test-godot
	@echo "ALL TESTS PASSED"

# Prefer native Wayland so trackpad MagnifyGesture (pinch-zoom) actually arrives.
# Under XWayland, Godot often never sees InputEventMagnifyGesture.
run: build import
	@if [ -n "$$WAYLAND_DISPLAY" ]; then \
		$(GODOT) --display-driver wayland --path game; \
	else \
		$(GODOT) --path game; \
	fi

# UI demo movies (needs display/GPU + ffmpeg). Window is minimized by default.
# SX_TEST_WINDOW=onscreen to watch; SX_MOVIES_XVFB=1 if xvfb-run is installed.
movies: import
	chmod +x scripts/sx-movies
	./scripts/sx-movies all

# Extract posters into solidexpress.github.io and upload WebMs to Release tag demo-movies.
publish-demo-movies:
	chmod +x scripts/sx-publish-demo-movies
	./scripts/sx-publish-demo-movies

# Copy canonical website/ into a solidexpress.github.io checkout (SX_SITE_ROOT).
sync-website:
	chmod +x scripts/sx-sync-website
	./scripts/sx-sync-website

# Fail if the marketing site would show a demo whose WebM/poster is missing.
check-website-demos:
	chmod +x scripts/sx-check-website-demos
	./scripts/sx-check-website-demos

fetch-godot-templates:
	chmod +x scripts/release/fetch-godot-templates.sh
	./scripts/release/fetch-godot-templates.sh

release-linux: fetch-godot-templates
	chmod +x scripts/release/export-linux.sh
	./scripts/release/export-linux.sh

clean:
	rm -rf $(BUILD_DIR)
