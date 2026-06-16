# frozen_string_literal: true

require_relative "display_text"
require_relative "style"
require_relative "modal"

module TuiTui
  # Key-binding cheat sheet modal.
  class Help < Modal
    COLGAP = 2

    def initialize(title, entries, theme: Theme::DEFAULT)
      @title = DisplayText.new(title)
      @entries = entries.map { |keys, desc| [DisplayText.new(keys), DisplayText.new(desc)] }
      @theme = theme
    end

    def handle(_key) = :close

    # Any click dismisses the sheet, like any key does.
    def handle_mouse(event) = event.action == :press ? :close : nil

    def draw(canvas, size)
      key_w = @entries.map { |keys, _| keys.width }.max || 0
      body_w = @entries.map { |keys, desc| keys.width + COLGAP + desc.width }.max || 0
      inner = [@title.width, body_w].max

      rect, col = panel(canvas, inner: inner, body_rows: @entries.size + 2)

      canvas.text(rect.row + 1, col, @title.truncate(inner), theme.title)
      draw_entries(canvas, rect.row + 3, col, key_w)
      canvas
    end

    private

    def draw_entries(canvas, row, col, key_w)
      @entries.each_with_index do |(keys, desc), index|
        canvas.text(row + index, col, keys, theme.accent)
        canvas.text(row + index, col + key_w + COLGAP, desc, theme.muted)
      end
    end
  end
end
