# frozen_string_literal: true

require_relative "rect"
require_relative "line"
require_relative "scrollbar"

module TuiTui
  # Drawing companion for ScrollList.
  # Row content comes from the caller, keeping the list domain-agnostic.
  class List
    def initialize(scroll)
      @scroll = scroll
    end

    def draw(canvas, rect, highlight: nil, scrollbar: nil)
      body, gutter = scrollbar ? rect.split_gutter : [rect, nil]
      @scroll.ensure_visible(body.rows)
      @scroll.each_visible(body.rows) do |index, offset|
        row = body.row + offset
        selected = index == @scroll.cursor
        canvas.fill(Rect.new(row: row, col: body.col, rows: 1, cols: body.cols), highlight) if highlight && selected
        canvas.line(row, body.col, as_line(yield(index, selected)).truncate(body.cols))
      end

      draw_scrollbar(canvas, gutter, scrollbar) if gutter
      canvas
    end

    # Map a MouseEvent to the list index under it, or nil. Pass the same `rect`
    # and `scrollbar:` used for `draw` so the gutter column is excluded and the
    # scroll offset matches what was rendered. Returns nil for clicks outside the
    # body or below the last item.
    def index_at(rect, event, scrollbar: nil)
      body = scrollbar ? rect.split_gutter.first : rect
      return nil unless body.hit?(event)

      index = @scroll.top + (event.row - body.row)
      index < @scroll.count ? index : nil
    end

    private

    def draw_scrollbar(canvas, gutter, theme)
      Scrollbar.draw(
        canvas,
        gutter,
        top: @scroll.top,
        visible: gutter.rows,
        total: @scroll.count,
        track_style: theme.scroll_track,
        thumb_style: theme.scroll_thumb
      )
    end

    def as_line(content) = content.is_a?(Line) ? content : Line.new(Array(content))
  end
end
