# frozen_string_literal: true

require_relative "width"
require_relative "text_sanitizer"
require_relative "display_text"
require_relative "style"
require_relative "cell"
require_relative "box_chrome"

module TuiTui
  # Pure drawing surface. Coordinates are 1-origin to match terminal cursor
  # addressing, and text layout is terminal-column aware.
  class Canvas
    # Control bytes are rendered visibly instead of being emitted to the terminal.
    CONTROL_GLYPH = "?"
    FRAME = Style.new(fg: :bright_black)

    def self.blank(size, chrome: BoxChrome::ASCII)
      new(size.rows, size.cols, chrome: chrome)
    end

    attr_reader :rows, :cols
    attr_reader :cursor
    attr_reader :chrome

    def initialize(rows, cols, chrome: BoxChrome::ASCII)
      @rows = rows
      @cols = cols
      @grid = Array.new(rows) { Array.new(cols, Cell::BLANK) }
      @cursor = nil
      @chrome = chrome
    end

    def cursor_at(row, col)
      @cursor = [row, col] if row.between?(1, @rows) && col.between?(1, @cols)
      self
    end

    def cell(row, col)
      return nil unless row.between?(1, @rows) && col.between?(1, @cols)

      @grid[row - 1][col - 1]
    end

    def text(row, col, string, style = nil)
      return self unless row.between?(1, @rows)

      column = col
      TextSanitizer.sanitize(string.to_s).each_grapheme_cluster do |grapheme|
        if Width.control?(grapheme.ord)
          break if column > @cols

          place(row, column, Cell.new(char: CONTROL_GLYPH, style: style))
          column += 1
          next
        end

        width = Width.cluster(grapheme)
        # Leading combining marks have no base cell to attach to.
        next if width.zero?

        break if column > @cols
        # Do not split a wide glyph across the right edge.
        break if width == 2 && column == @cols

        place(row, column, Cell.new(char: grapheme, style: style))
        place(row, column + 1, Cell.new(char: nil, style: style)) if width == 2
        column += width
      end

      self
    end

    def line(row, col, spans)
      column = col
      spans.each do |span|
        text(row, column, span.text, span.style)
        column += DisplayText.new(span.text).width
      end

      self
    end

    def fill(rect, style, char = " ")
      cell = Cell.new(char: fill_char(char), style: style)
      rect.rows.times do |dr|
        row = rect.row + dr
        rect.cols.times { |dc| place(row, rect.col + dc, cell) }
      end

      self
    end

    def hline(row, col, len, char = "-", style = nil)
      text(row, col, char * len, style)
    end

    def frame(rect, style: FRAME, chrome: @chrome)
      fill(rect, nil)
      mid = chrome.h * (rect.cols - 2)
      text(rect.row, rect.col, chrome.tl + mid + chrome.tr, style)
      text(rect.row + rect.rows - 1, rect.col, chrome.bl + mid + chrome.br, style)
      (1...(rect.rows - 1)).each do |dy|
        text(rect.row + dy, rect.col, chrome.v, style)
        text(rect.row + dy, rect.col + rect.cols - 1, chrome.v, style)
      end

      self
    end

    def same_row?(other, r)
      grid_row(r) == other.grid_row(r)
    end

    def same_size?(other)
      @rows == other.rows && @cols == other.cols
    end

    # The changed column span of row `r` versus `other`, as [from, to] (1-origin,
    # inclusive), or nil if the row is identical. The start is backed up off any
    # wide-char continuation cell so a partial repaint never begins mid-glyph.
    # Used by the compositor to repaint only the part of a row that moved.
    def changed_span(other, r)
      mine = grid_row(r)
      theirs = other.grid_row(r)
      first = last = nil
      mine.each_index do |i|
        next if mine[i] == theirs[i]

        first ||= i
        last = i
      end

      return nil if first.nil?

      first -= 1 while first.positive? && mine[first].continuation?
      [first + 1, last + 1]
    end

    # Render row `r`, or just the column span [from, to], coalescing same-styled
    # runs and skipping wide-char continuation cells.
    def render_row(r, from: 1, to: @cols, depth: :ansi256, enabled: true)
      out = +""
      run = +""
      run_style = :none
      grid_row(r)[(from - 1)..(to - 1)].each do |c|
        next if c.continuation?

        if run_style != :none && run_style != c.style
          out << paint(run, run_style, depth, enabled)
          run = +""
        end

        run_style = c.style
        run << c.char
      end

      out << paint(run, run_style, depth, enabled) unless run.empty?
      out
    end

    def grid_row(r) = @grid[r - 1]

    private

    # A fill glyph with any control bytes replaced by CONTROL_GLYPH, so `fill`
    # upholds the same "Canvas never emits a raw control byte" guarantee as
    # `text` (cheap: computed once per fill, not per cell).
    def fill_char(char)
      char.to_s.each_char.map { |c| Width.control?(c.ord) ? CONTROL_GLYPH : c }.join
    end

    def place(row, col, cell)
      return unless row.between?(1, @rows) && col.between?(1, @cols)

      grid_row = @grid[row - 1]
      # Overwriting one half of a wide glyph orphans the other; blank it so the
      # row keeps its column count (no stale continuation, no half-glyph).
      grid_row[col] = Cell::BLANK if col < @cols && grid_row[col].continuation?
      grid_row[col - 2] = Cell::BLANK if col >= 2 && grid_row[col - 1].continuation?
      grid_row[col - 1] = cell
    end

    def paint(text, style, depth, enabled)
      return text if style.nil? || style == :none

      style.paint(text, depth: depth, enabled: enabled)
    end
  end
end
