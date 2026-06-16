# frozen_string_literal: true

require_relative "ansi"

module TuiTui
  # Builds the terminal update string.
  # Same-size frames repaint only changed column spans of changed rows.
  class CanvasCompositor
    def initialize(depth: :ansi256)
      @depth = depth
    end

    def render(previous, canvas)
      out = +""
      if full_repaint?(previous, canvas)
        out << Ansi::CLEAR
        (1..canvas.rows).each { |row| out << row_paint(canvas, row) }
      else
        (1..canvas.rows).each { |row| out << row_diff(canvas, previous, row) }
      end

      out
    end

    private

    def full_repaint?(previous, canvas)
      previous.nil? || !previous.same_size?(canvas)
    end

    # The whole row, positioned at column 1 (used for a full repaint).
    def row_paint(canvas, row)
      Ansi.move(row, 1) + canvas.render_row(row, depth: @depth, enabled: true)
    end

    # Only the changed span of `row`, positioned at its first changed column; ""
    # when the row is unchanged.
    def row_diff(canvas, previous, row)
      span = canvas.changed_span(previous, row)
      return "" unless span

      Ansi.move(row, span.first) + canvas.render_row(row, from: span.first, to: span.last, depth: @depth, enabled: true)
    end
  end
end
