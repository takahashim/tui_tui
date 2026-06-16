# frozen_string_literal: true

require_relative "display_text"
require_relative "style"
require_relative "modal"
require_relative "key_code"

module TuiTui
  # Single-line text input modal with terminal-column-aware cursor placement.
  class Prompt < Modal
    MIN_INNER = 24

    def initialize(label, value: "", theme: Theme::DEFAULT)
      @label = DisplayText.new(label)
      @graphemes = value.grapheme_clusters
      @pos = @graphemes.length
      @theme = theme
    end

    def value = @graphemes.join

    def handle(key)
      case key
      when "\r"
        [:ok, value]
      when :escape, KeyCode::CTRL_C
        :cancel
      when KeyCode::BACKSPACE, :backspace
        edit { delete_back }
      when :delete
        edit { delete_forward }
      when :left
        edit { @pos = [@pos - 1, 0].max }
      when :right
        edit { @pos = [@pos + 1, @graphemes.length].min }
      when :home
        edit { @pos = 0 }
      when :end
        edit { @pos = @graphemes.length }
      when String
        edit { insert(key) if printable?(key) }
      end
    end

    def handle_mouse(event)
      return nil unless event.action == :press && @text_row == event.row

      edit { @pos = index_at(event.col - @text_col) }
    end

    def draw(canvas, size)
      inner = [MIN_INNER, @label.width + 1 + DisplayText.new(value).width].max
      rect, col = panel(canvas, inner: inner, body_rows: 1)

      canvas.text(rect.row + 1, col, @label, theme.title)
      @text_row = rect.row + 1
      @text_col = col + @label.width + 1
      canvas.text(@text_row, @text_col, value, theme.text)
      draw_cursor(canvas, @text_row, @text_col)
      canvas
    end

    private

    def edit
      yield
      nil
    end

    # Grapheme index whose left edge is closest to `rel` columns into the value.
    def index_at(rel)
      return 0 if rel <= 0

      width = 0
      @graphemes.each_with_index do |grapheme, i|
        w = DisplayText.new(grapheme).width
        return i if rel < width + ((w + 1) / 2)

        width += w
      end

      @graphemes.length
    end

    def draw_cursor(canvas, row, text_col)
      cursor_col = text_col + DisplayText.new(@graphemes[0...@pos].join).width
      canvas.text(row, cursor_col, @graphemes[@pos] || " ", theme.cursor)
    end

    def insert(string)
      head = @graphemes[0...@pos].join
      @graphemes = (head + string + @graphemes[@pos..].join).grapheme_clusters
      @pos = (head + string).grapheme_clusters.length
    end

    def delete_back
      return if @pos.zero?

      @graphemes.delete_at(@pos - 1)
      @pos -= 1
    end

    def delete_forward
      @graphemes.delete_at(@pos) if @pos < @graphemes.length
    end

    def printable?(string)
      string.bytes.all? { |byte| byte >= 0x20 && byte != 0x7F }
    end
  end
end
