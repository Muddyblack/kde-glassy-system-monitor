.PHONY: help view view-h view-hyprland settings-hyprland network-hyprland network install shaders config test parity benchmark soak gallery docs lint pack tag
.DEFAULT_GOAL := help

help: ## list targets
	@awk 'BEGIN{FS=":.*##"} /^[a-z][a-zA-Z0-9_-]+:.*##/ {printf "  make %-10s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

view: ## preview widget (planar)
	@if command -v nix >/dev/null 2>&1 && [ -f flake.nix ]; then \
	  nix run .#view; \
	else \
	  plasmoidviewer -a package -f planar; \
	fi

view-h: ## preview widget (horizontal)
	@if command -v nix >/dev/null 2>&1 && [ -f flake.nix ]; then \
	  nix run .#view -- horizontal; \
	else \
	  plasmoidviewer -a package -f horizontal; \
	fi

view-hyprland: ## run the Quickshell desktop widget (Hyprland or any wlroots/KWin session; Ctrl+C stops)
	@if command -v qs >/dev/null 2>&1; then \
	  bash "$(CURDIR)/hyprland/run.sh"; \
	else \
	  nix run .#view-hyprland; \
	fi

settings-hyprland: ## open the studio of the running Quickshell widget
	@if command -v qs >/dev/null 2>&1; then \
	  bash "$(CURDIR)/hyprland/run.sh" ipc call settings open; \
	else \
	  nix run .#view-hyprland -- ipc call settings open; \
	fi

network-hyprland: ## open the network window of the running Quickshell widget
	@if command -v qs >/dev/null 2>&1; then \
	  bash "$(CURDIR)/hyprland/run.sh" ipc call network open; \
	else \
	  nix run .#view-hyprland -- ipc call network open; \
	fi

network: ## network window on demo data (SAVE=file.png TAB=apps to screenshot)
	@if command -v qml >/dev/null 2>&1; then \
	  tools/qml.sh tools/network.qml $(if $(SAVE),-- --save "$(abspath $(SAVE))" $(if $(TAB),--tab $(TAB))); \
	else \
	  nix develop --command tools/qml.sh tools/network.qml $(if $(SAVE),-- --save "$(abspath $(SAVE))" $(if $(TAB),--tab $(TAB))); \
	fi

install: ## install test copy to local Plasma session
	@./test_install.sh

shaders: ## rebuild the fragment shaders (needs qsb from the dev shell)
	@QSB=qsb; command -v qsb >/dev/null 2>&1 || QSB="nix develop --command qsb"; \
	for f in package/contents/shaders/*.frag; do \
	  $$QSB --glsl "100es,120,150" --hlsl 50 --msl 12 -o $$f.qsb $$f || exit 1; \
	done

parity: ## GPU shader vs Canvas, every chart style, live (opens a window; SAVE=file.png to screenshot)
	@if command -v qml >/dev/null 2>&1; then \
	  tools/qml.sh tools/parity.qml $(if $(SAVE),-- --save "$(abspath $(SAVE))"); \
	else \
	  nix develop --command tools/qml.sh tools/parity.qml $(if $(SAVE),-- --save "$(abspath $(SAVE))"); \
	fi

benchmark: ## CPU of GPU shader vs Canvas renderer (opens windows; keep them visible)
	@if command -v qml >/dev/null 2>&1; then \
	  tools/benchmark.sh $(or $(SECONDS),20); \
	else \
	  nix develop --command tools/benchmark.sh $(or $(SECONDS),20); \
	fi

soak: ## studio edits in a real GPU window; fails if one stalls (EDITS=40; not offscreen/software)
	@if command -v qml >/dev/null 2>&1; then \
	  QML_XHR_ALLOW_FILE_READ=1 tools/qml.sh tools/soak.qml -- --edits $(or $(EDITS),40); \
	else \
	  nix develop --command env QML_XHR_ALLOW_FILE_READ=1 tools/qml.sh tools/soak.qml -- --edits $(or $(EDITS),40); \
	fi

gallery: ## capture the README screenshots into docs/readme (opens windows)
	@if command -v qml >/dev/null 2>&1; then \
	  tools/gallery.sh; \
	else \
	  nix develop --command tools/gallery.sh; \
	fi

docs: ## build the website (docs/website) from the studio sources; then open docs/website/index.html
	@if command -v node >/dev/null 2>&1; then \
	  node tools/build_site.mjs; \
	else \
	  nix shell nixpkgs#nodejs --command node tools/build_site.mjs; \
	fi

lint: ## qmllint every QML file (syntax errors fail)
	@tools/lint.sh

config: ## regenerate the Plasma settings page's key list from main.xml
	@python3 tools/config_keys.py

test: ## run the full test suite
	@python3 tools/config_keys.py --check
	@if command -v qmltestrunner >/dev/null 2>&1; then \
	  QT_TOOL=qmltestrunner QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QML_XHR_ALLOW_FILE_READ=1 tools/qml.sh -input tests; \
	else \
	  nix develop --command env QT_TOOL=qmltestrunner QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QML_XHR_ALLOW_FILE_READ=1 tools/qml.sh -input tests; \
	fi

pack: ## build .plasmoid archive
	@if command -v nix >/dev/null 2>&1 && [ -f flake.nix ]; then \
	  nix run .#pack; \
	else \
	  ver=$$(grep -oE '"Version":[[:space:]]*"[^"]+"' package/metadata.json | head -1 | sed -E 's/.*"([^"]+)"$$/\1/'); \
	  name=$$(basename "$$PWD"); \
	  out="$$PWD/$$name-$$ver.plasmoid"; \
	  rm -f "$$out"; \
	  (cd package && zip -r "$$out" . -x '*.swp' '*~'); \
	  echo "wrote $$out"; \
	fi

tag: ## bump version, commit, tag, push
	@./tag.sh
