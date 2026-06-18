# frozen_string_literal: true

require_relative "line"
require_relative "span"
require_relative "scrollbar"

module TuiTui
  # A scrolled read-only text window.
  # Lines may be Strings, Lines, or Span arrays, supplied eagerly or lazily.
  module TextView
    module_function

    def draw(canvas, rect, lines = nil, top: 0, style: nil, scrollbar: nil, total: nil, auto: false)
      # With auto:, reserve the gutter only when the content overflows the rect.
      # When the total is unknown (lazy block, no total:), the bar is kept.
      count = total || lines&.length
      show_bar = scrollbar && !(auto && count && count <= rect.rows)
      body, gutter = show_bar ? rect.split_gutter : [rect, nil]
      body.rows.times do |offset|
        index = top + offset
        content = lines ? lines[index] : yield(index)
        next if content.nil?

        canvas.line(body.row + offset, body.col, Line.coerce(content, style).truncate(body.cols))
      end

      draw_scrollbar(canvas, gutter, top, total || lines&.length, body.rows, scrollbar) if gutter
      canvas
    end

    def draw_scrollbar(canvas, gutter, top, total, visible, theme)
      return unless total

      Scrollbar.draw(
        canvas,
        gutter,
        top: top,
        visible: visible,
        total: total,
        track_style: theme.scroll_track,
        thumb_style: theme.scroll_thumb
      )
    end
  end
end
