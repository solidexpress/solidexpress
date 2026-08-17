BUILD_DIR := build
GODOT := tools/godot/godot
JOBS := $(shell nproc)

.PHONY: all configure build test test-kernel test-godot clean import movies publish-demo-movies sync-website check-website-demos release-linux fetch-godot-templates

VERSION := $(shell cat VERSION 2>/dev/null || echo 0.0.0-dev)

all: build

configure:
	cmake -S . -B $(BUILD_DIR) -G Ninja

build: configure
	cmake --build $(BUILD_DIR) -j $(JOBS)

test-kernel: build
	./$(BUILD_DIR)/sxkernel/sxkernel_tests
	./$(BUILD_DIR)/sxvoice/sxvoice_tests

# First import bakes .godot cache; needed once before running scripts headless.
import: build
	$(GODOT) --headless --path game --import > /dev/null 2>&1 || true

test-godot: build import
	$(GODOT) --headless --path game --script tests/run_parse_sweep_tests.gd
	$(GODOT) --headless --path game --script tests/run_tests.gd
	$(GODOT) --headless --path game --script tests/run_ui_tests.gd
	$(GODOT) --headless --path game --script tests/run_sketch_tests.gd
	$(GODOT) --headless --path game --script tests/run_sketch_tools_tests.gd
	$(GODOT) --headless --path game --script tests/run_sketch_parity_tests.gd
	$(GODOT) --headless --path game --script tests/run_sketch_fully_defined_tests.gd
	$(GODOT) --headless --path game --script tests/run_sketch_expr_dim_tests.gd
	$(GODOT) --headless --path game --script tests/run_convert_entities_tests.gd
	$(GODOT) --headless --path game --script tests/run_sweep_loft_solid_tests.gd
	$(GODOT) --headless --path game --script tests/run_mirror_feature_tests.gd
	$(GODOT) --headless --path game --script tests/run_hole_wizard_tests.gd
	$(GODOT) --headless --path game --script tests/run_pliers_motion_tests.gd
	$(GODOT) --headless --path game --script tests/run_display_tests.gd
	$(GODOT) --headless --path game --script tests/run_menu_tests.gd
	$(GODOT) --headless --path game --script tests/run_workflow_tests.gd
	$(GODOT) --headless --path game --script tests/run_select_tests.gd
	$(GODOT) --headless --path game --script tests/run_property_tests.gd
	$(GODOT) --headless --path game --script tests/run_infer_tests.gd
	$(GODOT) --headless --path game --script tests/run_mate_tests.gd
	$(GODOT) --headless --path game --script tests/run_camera_tests.gd
	$(GODOT) --headless --path game --script tests/run_help_tests.gd
	$(GODOT) --headless --path game --script tests/run_place_tests.gd
	$(GODOT) --headless --path game --script tests/run_layout_tests.gd
	$(GODOT) --headless --path game --script tests/run_icon_tests.gd
	$(GODOT) --headless --path game --script tests/run_visibility_tests.gd
	$(GODOT) --headless --path game --script tests/run_viewcube_tests.gd
	$(GODOT) --headless --path game --script tests/run_assembly_tests.gd
	$(GODOT) --headless --path game --script tests/run_insert_component_tests.gd
	$(GODOT) --headless --path game --script tests/run_drag_tests.gd
	$(GODOT) --headless --path game --script tests/run_voice_tests.gd
	$(GODOT) --headless --path game --script tests/run_catalog_tool_tests.gd
	$(GODOT) --headless --path game --script tests/run_howto_tests.gd
	$(GODOT) --headless --path game --script tests/run_print_tests.gd
	$(GODOT) --headless --path game --script tests/run_construction_tests.gd
	$(GODOT) --headless --path game --script tests/run_wrench_chrome_tests.gd
	$(GODOT) --headless --path game --script tests/run_clearance_tests.gd
	$(GODOT) --headless --path game --script tests/run_see_the_print_tests.gd
	$(GODOT) --headless --path game --script tests/run_sketch_to_3d_ui_tests.gd
	$(GODOT) --headless --path game --script tests/run_ui_button_coverage_tests.gd
	$(GODOT) --headless --path game --script tests/run_film_manifest_smoke.gd
	$(GODOT) --headless --path game --script tests/run_visual_ux_tests.gd
	$(GODOT) --headless --path game --script tests/run_move_snap_tests.gd
	$(GODOT) --headless --path game --script tests/run_timeline_ux_tests.gd
	$(GODOT) --headless --path game --script tests/run_measure_overlay_tests.gd
	$(GODOT) --headless --path game --script tests/run_open_in_slicer_tests.gd
	$(GODOT) --headless --path game --script tests/run_clearance_tests.gd
	$(GODOT) --headless --path game --script tests/run_dead_chrome_tests.gd
	$(GODOT) --headless --path game --script tests/run_mechanic_blocker_tests.gd
	$(GODOT) --headless --path game --script tests/run_wrench_cut_tests.gd
	$(GODOT) --headless --path game --script tests/run_chamfer_sketch_layout_tests.gd

test: test-kernel test-godot
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
