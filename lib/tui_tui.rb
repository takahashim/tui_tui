# frozen_string_literal: true

require_relative "tui_tui/version"

require_relative "tui_tui/clock"
require_relative "tui_tui/width"
require_relative "tui_tui/text_sanitizer"
require_relative "tui_tui/display_text"
require_relative "tui_tui/span"
require_relative "tui_tui/line"
require_relative "tui_tui/ansi"
require_relative "tui_tui/color_depth"
require_relative "tui_tui/box_chrome"
require_relative "tui_tui/box_prober"
require_relative "tui_tui/palette"
require_relative "tui_tui/style"
require_relative "tui_tui/theme"
require_relative "tui_tui/size"
require_relative "tui_tui/rect"
require_relative "tui_tui/cell"
require_relative "tui_tui/canvas"
require_relative "tui_tui/render_context"
require_relative "tui_tui/canvas_compositor"
require_relative "tui_tui/event"
require_relative "tui_tui/key_code"
require_relative "tui_tui/key_reader"
require_relative "tui_tui/key_intent"
require_relative "tui_tui/event_stream"
require_relative "tui_tui/terminal_session"
require_relative "tui_tui/scroll_list"
require_relative "tui_tui/list"
require_relative "tui_tui/text_view"
require_relative "tui_tui/scrollbar"
require_relative "tui_tui/status_bar"
require_relative "tui_tui/toast"
require_relative "tui_tui/focus_ring"
require_relative "tui_tui/fuzzy"
require_relative "tui_tui/modal"
require_relative "tui_tui/modal_host"
require_relative "tui_tui/confirm"
require_relative "tui_tui/select"
require_relative "tui_tui/command_palette"
require_relative "tui_tui/help"
require_relative "tui_tui/prompt"
require_relative "tui_tui/pager"
require_relative "tui_tui/screen"
require_relative "tui_tui/runtime"

# A tiny, owned TUI runtime for rendering in modern graphical terminals. Its only
# dependency is `io/console` (a default gem, used by the Screen driver); the pure
# pieces — width, color, style, layout — need nothing.
#
# The framework is application-agnostic. Build an app object responding to
# `view(size) -> Canvas` and `update(event) -> app | :quit`, then drive it with
# `TuiTui::Runtime`.
module TuiTui
end
