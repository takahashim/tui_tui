# frozen_string_literal: true

require_relative "event"

module TuiTui
  # Host-side helper for the app that *owns* the current modal widget.
  #
  # Centralizes the open + dispatch loop every app with modals otherwise hand
  # writes: it routes MouseEvents to #handle_mouse and other events to #handle,
  # honors the "resolved value, or nil to stay open" widget contract, and runs
  # the caller's on_result callback when the modal resolves.
  #
  #   host = TuiTui::ModalHost.new
  #   host.open(TuiTui::Confirm.new("Quit?")) { |r| :quit if r == :ok }
  #   # in update(event):
  #   if host.open?
  #     outcome = host.handle(event)   # nil while open; on_result value once resolved
  #     return outcome == :quit ? :quit : self
  #   end
  #   # in view(size): host.draw(canvas, size) if host.open?
  class ModalHost
    def open(widget, &on_result)
      @widget = widget
      @on_result = on_result || ->(result) { result }
      self
    end

    def open? = !@widget.nil?

    def close
      @widget = nil
      @on_result = nil
    end

    def draw(canvas, size) = @widget&.draw(canvas, size)

    # Route one event to the modal. Returns nil while the modal stays open
    # (the event was consumed), or the on_result callback's value once the
    # widget resolves (e.g. :quit, or a new app model).
    def handle(event)
      return nil unless open?

      result = dispatch(event)
      return nil if result.nil?

      callback = @on_result
      close
      callback.call(result)
    end

    private

    def dispatch(event)
      case event
      when MouseEvent then @widget.handle_mouse(event)
      when KeyEvent then @widget.handle(event.key)
      else @widget.handle(event)
      end
    end
  end
end
