# frozen_string_literal: true

require "io/console"

require_relative "ansi"
require_relative "size"
require_relative "color_depth"
require_relative "canvas_compositor"
require_relative "terminal_size"
require_relative "event_stream"
require_relative "terminal_session"

module TuiTui
  # Terminal-facing screen owner: session lifecycle, event stream, and rendering.
  class Screen
    DEFAULT_SIZE = Size.new(rows: 24, cols: 80)

    def self.run(input: $stdin, output: $stdout, depth: ColorDepth.detect, mouse: mouse_default)
      console = IO.console
      # Let callers provide a non-interactive fallback for piped output.
      return yield(nil) if console.nil? || !output.tty?

      screen = new(console, input, output, depth, mouse: mouse)
      screen.start
      begin
        yield screen
      ensure
        screen.close
      end
    end

    def self.mouse_default
      !%w[0 off false].include?(ENV["TUITUI_MOUSE"])
    end

    def initialize(console, input, output, depth, mouse: true)
      @output = output
      @compositor = CanvasCompositor.new(depth: depth)
      @term_size = TerminalSize.new(console, default: DEFAULT_SIZE)
      @events = EventStream.new(input: input, size: @term_size)
      @session = TerminalSession.new(console: console, output: output, events: @events, mouse: mouse)
      @previous = nil
      # the cursor position last written (the session starts it hidden)
      @cursor = nil
    end

    attr_reader :events

    def start = @session.start

    def size = @term_size.size

    # Render `canvas`: the compositor computes the (full or per-row diff) escape
    # string, then the cursor is repositioned (or hidden). The cursor directive
    # is appended only on a full repaint or when the cursor actually moved, so an
    # idle identical re-render still writes nothing.
    def render(canvas)
      full = @previous.nil? || !@previous.same_size?(canvas)
      out = @compositor.render(@previous, canvas)
      out += cursor_directive(canvas) if full || canvas.cursor != @cursor
      @output.write(out)
      @output.flush
      @previous = canvas
      @cursor = canvas.cursor
    end

    def invalidate
      @previous = nil
    end

    def copy(text)
      @output.write(Ansi.clipboard(text))
      @output.flush
    end

    def close = @session.close

    private

    def cursor_directive(canvas)
      pos = canvas.cursor
      pos ? Ansi.move(pos[0], pos[1]) + Ansi::SHOW : Ansi::HIDE
    end
  end
end
