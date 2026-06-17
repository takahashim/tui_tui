# Changelog

## [0.2.0] - 2026-06-17

### Added
- Optional Unicode box-drawing chrome: probed once at startup and used only when
  the terminal renders it at width 1, else ASCII. Override with `TUITUI_BOX`.
- `RenderContext` passed to `view` (a `Size`-compatible value with a `canvas`
  factory); legacy `view(size)` apps keep working.
- `Rect#include?(row, col)` and `Rect#hit?(mouse_event)` for mouse hit-testing.
- `List#index_at(rect, event, scrollbar:)` to map a click to a list index,
  accounting for the scroll offset and the scrollbar gutter.
- `Theme` semantic status roles — `success` / `warning` / `danger` / `info`
  (background-aware, hue-independent) — plus `Theme#status(kind)` to map
  symbolic kinds (`:ok`, `:warn`, `:error`, `:info`, with aliases) to a role.
- `ModalHost`: a host-side helper that owns the current modal widget, routing
  `MouseEvent`s to `#handle_mouse` and other events to `#handle`, and running an
  `on_result` callback when the widget resolves.
- `auto:` option for `List.draw` / `TextView.draw`: reserve the scrollbar gutter
  only when the content overflows the rect.

### Fixed
- Silence the "method redefined; discarding old []" warning from `Span` under
  `-w` by removing the `Data`-generated `.[]` before redefining the convenience
  constructor.

## [0.1.0] - 2026-06-16

### Added
- Initial release: a lightweight, dependency-free (io/console only) TEA-inspired
  (MVU) TUI toolkit — Canvas with per-cell diffing, Theme, layout `Rect`s,
  widgets (List, TextView, Scrollbar, StatusBar, Toast, Modal, Confirm, Select,
  Help, Prompt, Pager, Fuzzy), East-Asian-width-aware text, and a `Runtime`
  event loop.
