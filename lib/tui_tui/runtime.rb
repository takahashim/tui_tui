# frozen_string_literal: true

require_relative "screen"
require_relative "render_context"

module TuiTui
  # Small Elm-style loop: render, read one event, fold it through the app, repeat.
  class Runtime
    def initialize(app)
      @app = app
    end

    def run(input: $stdin, output: $stdout, depth: ColorDepth.detect, tick: 0.1, mouse: Screen.mouse_default, box: ENV["TUITUI_BOX"])
      Screen.run(input: input, output: output, depth: depth, mouse: mouse, box: box) do |screen|
        raise "tui_tui: not a terminal" if screen.nil?

        screen.render(view(screen))
        loop do
          event = screen.events.next_event(tick: tick)
          break if event.is_a?(EofEvent)
          next if inert_tick?(event)

          screen.invalidate if wants_redraw?(event)
          result = @app.update(event)
          break if result == :quit || result.nil?

          @app = result
          flush_clipboard(screen)
          screen.render(view(screen))
        end
      end
    end

    private

    # Pass a RenderContext (size + resolved chrome + canvas factory). It is
    # Size-compatible, so legacy `view(size)` apps keep working (ASCII).
    def view(screen)
      @app.view(RenderContext.new(size: screen.size, chrome: screen.chrome))
    end

    def flush_clipboard(screen)
      # Clipboard writes stay an effect of the loop, requested by the app.
      return unless @app.respond_to?(:take_clipboard)

      text = @app.take_clipboard
      screen.copy(text) if text
    end

    def wants_redraw?(event)
      @app.respond_to?(:redraw?) && @app.redraw?(event)
    end

    def inert_tick?(event)
      # Ticks are opt-in: a TickEvent is inert unless the app explicitly wants it
      # (so a plain app like counter.rb never redraws on the timer).
      event.is_a?(TickEvent) && !(@app.respond_to?(:wants_tick?) && @app.wants_tick?)
    end
  end
end
