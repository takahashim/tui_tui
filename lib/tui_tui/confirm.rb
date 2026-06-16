# frozen_string_literal: true

require_relative "display_text"
require_relative "style"
require_relative "modal"
require_relative "key_code"

module TuiTui
  # OK / Cancel confirmation modal.
  class Confirm < Modal
    GAP = 2

    attr_reader :focus

    def initialize(message, ok: "OK", cancel: "Cancel", default: :cancel, theme: Theme::DEFAULT)
      @message = DisplayText.new(message)
      @ok = button_text(ok)
      @cancel = button_text(cancel)
      @focus = default
      @theme = theme
    end

    def handle(key)
      case key
      when :left, :right, "\t", "h", "l"
        toggle
      when "\r", " "
        @focus
      when "y", "Y"
        :ok
      when "n", "N", :escape, KeyCode::CTRL_C
        :cancel
      end
    end

    def handle_mouse(event)
      return nil unless event.action == :press && @buttons_row == event.row

      return :ok if hit?(event.col, @ok_at, @ok.width)
      return :cancel if hit?(event.col, @cancel_at, @cancel.width)

      nil
    end

    def draw(canvas, size)
      inner = [@message.width, buttons_width].max
      rect, col = panel(canvas, inner: inner, body_rows: 3)
      canvas.text(rect.row + 1, col, @message.center(inner), theme.text)
      draw_buttons(canvas, rect.row + 3, col, inner)
      canvas
    end

    private

    def hit?(col, start, width) = col.between?(start, start + width - 1)

    def toggle
      @focus = @focus == :ok ? :cancel : :ok
      nil
    end

    def draw_buttons(canvas, row, col, inner)
      start = col + [(inner - buttons_width) / 2, 0].max
      @buttons_row = row
      @ok_at = start
      @cancel_at = start + @ok.width + GAP
      canvas.text(row, @ok_at, @ok, @focus == :ok ? theme.selection : theme.text)
      canvas.text(row, @cancel_at, @cancel, @focus == :cancel ? theme.selection : theme.text)
    end

    def buttons_width = @ok.width + GAP + @cancel.width
    def button_text(label) = DisplayText.new("[ #{label} ]")
  end
end
