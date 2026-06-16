# frozen_string_literal: true

module TuiTui
  # A 1-origin screen rectangle with pure layout helpers.
  Rect = Data.define(:row, :col, :rows, :cols) do
    def self.centered(within, cols:, rows:)
      new(
        row: [((within.rows - rows) / 2) + 1, 1].max,
        col: [((within.cols - cols) / 2) + 1, 1].max,
        rows: rows,
        cols: cols
      )
    end

    def split_h(top_rows)
      top = Rect.new(row: row, col: col, rows: top_rows, cols: cols)
      bottom = Rect.new(row: row + top_rows, col: col, rows: rows - top_rows, cols: cols)
      [top, bottom]
    end

    def split_v(left_cols)
      left = Rect.new(row: row, col: col, rows: rows, cols: left_cols)
      right = Rect.new(row: row, col: col + left_cols, rows: rows, cols: cols - left_cols)
      [left, right]
    end

    # Split into [left, right] by `ratio` of the width
    def split_ratio(ratio, min: 0, gutter: 0)
      lo = min
      hi = cols - min - gutter
      left_cols = hi < lo ? cols / 2 : (cols * ratio).round.clamp(lo, hi)
      left, right = split_v(left_cols)
      [left, right.shift_right(gutter)]
    end

    def shift_right(by)
      Rect.new(row: row, col: col + by, rows: rows, cols: cols - by)
    end

    # Whether a 1-origin cell (row, col) falls inside this rectangle.
    def include?(r, c)
      r.between?(row, row + rows - 1) && c.between?(col, col + cols - 1)
    end

    # Whether a MouseEvent's cell falls inside this rectangle.
    def hit?(mouse) = include?(mouse.row, mouse.col)

    # Carve `width` columns off the right edge for a scrollbar gutter. Returns
    # [body, gutter]; gutter is nil when the rect is too narrow to spare them.
    def split_gutter(width = 1)
      return [self, nil] if cols <= width

      [with(cols: cols - width), Rect.new(row: row, col: col + cols - width, rows: rows, cols: width)]
    end
  end
end
