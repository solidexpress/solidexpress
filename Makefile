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
	$(GODOT) --headless --path game --script tests/run_body_move_click_tests.gd
	$(GODOT) --headless --path game --script tests/run_move_snap_tests.gd
	$(GODOT) --headless --path game --script tests/run_timeline_ux_tests.gd
	$(GODOT) --headless --path game --script tests/run_measure_overlay_tests.gd
	$(GODOT) --headless --path game --script tests/run_open_in_slicer_tests.gd
	$(GODOT) --headless --path game --script tests/run_clearance_tests.gd
	$(GODOT) --headless --path game --script tests/run_dead_chrome_tests.gd
	$(GODOT) --headless --path game --script tests/run_mechanic_blocker_tests.gd
	$(GODOT) --headless --path game --script tests/run_wrench_cut_tests.gd
	$(GODOT) --headless --path game --script tests/run_chamfer_sketch_layout_tests.gd
	$(GODOT) --headless --path game --script tests/run_wrench_blockers_tests.gd
	$(GODOT) --headless --path game --script tests/run_critic_walk_tests.gd
	$(GODOT) --headless --path game --script tests/run_wrench_placement_tests.gd
	$(GODOT) --headless --path game --script tests/run_triball_hex_polish_tests.gd
	$(GODOT) --headless --path game --script tests/run_wrench_through_tests.gd
	$(GODOT) --headless --path game --script tests/run_rung01_chrome_tests.gd
	$(GODOT) --headless --path game --script tests/run_rung01_sketch_tests.gd
	$(GODOT) --headless --path game --script tests/run_rung01_fillet_tests.gd
	$(GODOT) --headless --path game --script tests/run_rung01_wrench.gd
	$(GODOT) --headless --path game --script tests/run_rung01_sx036_esc.gd
	$(GODOT) --headless --path game --script tests/run_rung01_jaw_label_hit.gd
	$(GODOT) --headless --path game --script tests/run_rung01_sx036_fields.gd
	$(GODOT) --headless --path game --script tests/run_rung01_replan_finishbar.gd
	$(GODOT) --headless --path game --script tests/run_rung01_replan_sketch.gd
	$(GODOT) --headless --path game --script tests/run_rung01_replan_input.gd
	$(GODOT) --headless --path game --script tests/run_rung01_replan_shell.gd
	$(GODOT) --headless --path game --script tests/run_rung01_replan_panel.gd
	$(GODOT) --headless --path game --script tests/run_rung01_replan2_distance.gd
	$(GODOT) --headless --path game --script tests/run_rung01_replan2_commit.gd
	$(GODOT) --headless --path game --script tests/run_rung01_replan2_pointer.gd
	$(GODOT) --headless --path game --script tests/run_rung01_replan2_shell.gd
	$(GODOT) --headless --path game --script tests/run_rung01_replan2_layout.gd
	$(GODOT) --headless --path game --script tests/run_rung01_replan2_camera.gd
	$(GODOT) --headless --path game --script tests/run_rung01_replan3_distance.gd
	$(GODOT) --headless --path game --script tests/run_rung01_replan3_input.gd
	$(GODOT) --headless --path game --script tests/run_rung01_replan3_blank.gd
	$(GODOT) --headless --path game --script tests/run_rung01_replan3_timeline.gd
	$(GODOT) --headless --path game --script tests/run_rung01_replan3_fillet.gd
	$(GODOT) --headless --path game --script tests/run_rung01_replan3_shell.gd
	$(GODOT) --headless --path game --script tests/run_rung01_replan4_numeric.gd
	$(GODOT) --headless --path game --script tests/run_rung01_replan4_dialog.gd
	$(GODOT) --headless --path game --script tests/run_rung01_replan4_smartdim.gd
	$(GODOT) --headless --path game --script tests/run_rung01_replan5_session.gd
	$(GODOT) --headless --path game --script tests/run_rung01_replan5_trim.gd
	$(GODOT) --headless --path game --script tests/run_rung01_replan5_smartdim.gd
	$(GODOT) --headless --path game --script tests/run_rung01_replan5_shell.gd
	$(GODOT) --headless --path game --script tests/run_rung01_replan5_face.gd
	$(GODOT) --headless --path game --script tests/run_rung01_replan6_cut.gd
	$(GODOT) --headless --path game --script tests/run_rung01_replan6_smartdim.gd
	$(GODOT) --headless --path game --script tests/run_rung01_replan6_export.gd
	$(GODOT) --headless --path game --script tests/run_rung01_replan6_chrome.gd
	@for f in game/tests/run_rung01_replan7_*.gd; do \
		[ -e "$$f" ] || continue; \
		$(GODOT) --headless --path game --script tests/$$(basename $$f) || exit 1; \
	done
	@for f in game/tests/run_rung01_replan8_*.gd; do \
		[ -e "$$f" ] || continue; \
		$(GODOT) --headless --path game --script tests/$$(basename $$f) || exit 1; \
	done
	@for f in game/tests/run_rung01_replan9_*.gd; do \
		[ -e "$$f" ] || continue; \
		$(GODOT) --headless --path game --script tests/$$(basename $$f) || exit 1; \
	done
	@for f in game/tests/run_rung01_replan10_*.gd; do \
		[ -e "$$f" ] || continue; \
		$(GODOT) --headless --path game --script tests/$$(basename $$f) || exit 1; \
	done
	@for f in game/tests/run_rung01_replan11_*.gd; do \
		[ -e "$$f" ] || continue; \
		$(GODOT) --headless --path game --script tests/$$(basename $$f) || exit 1; \
	done
	@for f in game/tests/run_rung01_replan12_*.gd; do \
		[ -e "$$f" ] || continue; \
		$(GODOT) --headless --path game --script tests/$$(basename $$f) || exit 1; \
	done
	@for f in game/tests/run_rung01_replan13_*.gd; do \
		[ -e "$$f" ] || continue; \
		$(GODOT) --headless --path game --script tests/$$(basename $$f) || exit 1; \
	done
	@for f in game/tests/run_rung01_replan14_*.gd; do \
		[ -e "$$f" ] || continue; \
		$(GODOT) --headless --path game --script tests/$$(basename $$f) || exit 1; \
	done
	@for f in game/tests/run_rung01_replan15_*.gd; do \
		[ -e "$$f" ] || continue; \
		$(GODOT) --headless --path game --script tests/$$(basename $$f) || exit 1; \
	done
	$(GODOT) --headless --path game --script tests/run_rung01_sx036_rail.gd

lint-rung01-e2e:
	python3 tools/lint_rung01_e2e.py

test-tools:
	@if [ -f tools/test_check_rung01.py ]; then python3 tools/test_check_rung01.py; fi

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
