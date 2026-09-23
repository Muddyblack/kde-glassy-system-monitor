# Contributing

Issues and pull requests are welcome. For anything bigger than a fix, open an issue first so we
can agree on the approach.

## Setup

```bash
nix develop            # Qt, qsb, plasmoidviewer, Quickshell tools (direnv loads it too)
make help              # every target
```

Without Nix you need Qt 6.7+ with `qmltestrunner`, `qmllint`, `qmlformat` and `qsb`, and Plasma 6.

## Running it

```bash
make view              # the widget in plasmoidviewer
make view-hyprland     # the widget on Quickshell
make network           # the network window on demo data
make install           # a test copy in your Plasma session (./test_install.sh)
```

## Checks

```bash
make test              # the full test suite (see tests/README.md)
make lint              # qmllint
make parity            # GPU shader vs canvas, every chart style
make benchmark         # CPU of both renderers (keep the windows visible)
make soak              # studio edits in a real GPU window
```

The pre-commit hooks run `qmlformat -i` and `qmllint` on staged QML files. CI runs the lint.

- `tools/qml.sh` keeps the desktop session's Qt out of the dev shell's tools; mixing the two
  crashes or fails to load modules. Use it (or the make targets) rather than calling `qml` directly.
- QML warnings are silent unless `QT_FORCE_STDERR_LOGGING=1` is set.
- The GPU chart path is skipped offscreen and on software rendering, so check shader and
  frosted-glass changes in a real window.

## Where things live

- `package/contents/ui/MonitorCore.qml`: all sampling, shared by every host
- `package/contents/ui/MonitorView.qml`: the card and its layout
- `package/contents/ui/diagram/`: charts (GPU shader and canvas)
- `package/contents/ui/studio/`: the settings studio
- `package/contents/ui/network/`: the network window
- `hyprland/`: the Quickshell host
- `docs/website/`: the website, built by `make docs`

Most of what defines the widget is plain JavaScript shared by the widget, both studios and the
website: settings ([`studio/Schema.js`](package/contents/ui/studio/Schema.js)), looks
([`studio/Looks.js`](package/contents/ui/studio/Looks.js)), sections
([`Sections.js`](package/contents/ui/Sections.js), [`SectionModels.js`](package/contents/ui/SectionModels.js))
and chart data ([`diagram/DiagramData.js`](package/contents/ui/diagram/DiagramData.js)).
`make docs` bundles them for the browser together with the shader, so a change there reaches the
website without a website edit. Put logic there rather than duplicating it in QML or `app.js`.

## Other targets

```bash
make shaders           # rebuild diagram.frag.qsb after editing the shader
make config            # regenerate the settings key list from main.xml
make gallery           # README screenshots into docs/readme
make docs              # website into docs/website
make pack              # .plasmoid for the KDE Store
```

By contributing you agree that your work is released under the
[GPL-3.0-or-later](LICENSE).
