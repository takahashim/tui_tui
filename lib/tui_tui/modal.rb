# frozen_string_literal: true

require_relative "rect"
require_relative "theme"

module TuiTui
  # Base protocol and shared centered-panel framing for overlay widgets.
  class Modal
    PAD = 2

    def handle(_key) = raise NotImplementedError, "#{self.class}#handle"

    # Optional mouse handling, same return contract as #handle (resolved value,
    # or nil to stay open). Default no-op so widgets opt in only as needed; the
    # host routes MouseEvents here and KeyEvents to #handle.
    def handle_mouse(_event) = nil

    def draw(_canvas, _size) = raise NotImplementedError, "#{self.class}#draw"

    private

    def theme = @theme || Theme::DEFAULT

    def panel(canvas, inner:, body_rows:)
      rect = Rect.centered(canvas, cols: inner + (PAD * 2) + 2, rows: body_rows + 2)
      canvas.frame(rect, style: theme.frame)
      [rect, rect.col + PAD + 1]
    end
  end
end
