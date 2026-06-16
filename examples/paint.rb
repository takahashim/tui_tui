#!/usr/bin/env ruby
# frozen_string_literal: true

# A mouse demo + color/style showcase. Drag in the canvas to paint cells;
# right-drag erases. Press `p` (or click the color swatch) to open a color
# picker dialog — a grid of all 256 terminal colors, choosable by arrows+Enter
# or a mouse click, and movable by dragging its title bar. The header row shows
# the text attributes as live samples.
# Cells (and swatches) are a space in a background color (ASCII-only, N7).
#
#   ruby examples/paint.rb
#
# Mouse: drag = paint, right-drag = erase, click the swatch = open colors.
# Keys: p colors, [ / ] brush size, c clear, q (or Ctrl-C) quit.

require_relative "../lib/tui_tui"

module PaintSample
  DIM = TuiTui::Style.new(attrs: [:dim])
  BAR = TuiTui::Style.new(attrs: [:reverse])
  TITLE = TuiTui::Style.new(attrs: [:bold])
  ATTRS = %i[bold dim italic underline reverse].freeze

  STYLES_ROW = 1
  STATUS_ROW = 2
  PAINT_TOP = 3
  SWATCH_COL = " color: ".length + 1 # the status-row swatch column (click to open)

  # A modal color picker: the 256 terminal colors as a 16-wide grid, chosen with
  # the arrow keys + Enter, or a mouse click. `handle` / `handle_mouse` return the
  # chosen color index, :cancel, or nil while still open. The grid geometry is
  # recorded at draw time so a click can be hit-tested against the current frame.
  class ColorPicker
    COLS = 16
    COUNT = 256
    SW = 2 # swatch width

    attr_reader :pos # [row, col] top-left, or nil if never moved (so the app can reopen it in place)

    def initialize(current: 0, pos: nil)
      @cursor = current
      @pos = pos  # [row, col] top-left once the dialog has been moved; nil = centered
      @rect = nil # the current frame rect, recorded at draw time for hit-testing
      @drag = nil # [dy, dx]: the pointer's offset within the dialog while dragging it
    end

    def handle(key)
      case key
      when :left then move(-1)
      when :right then move(1)
      when :up then move(-COLS)
      when :down then move(COLS)
      when "\r", " " then @cursor
      when :escape, TuiTui::KeyCode::CTRL_C then :cancel
      end
    end

    # Press on the title bar -> start moving the dialog; press on a swatch -> pick
    # it; drag -> move; release -> stop. Returns the chosen index, or nil (open).
    def handle_mouse(event)
      case event.action
      when :press then press(event)
      when :drag then continue_drag(event)
      when :release then end_drag
      end
    end

    def draw(canvas, size)
      @rect = frame_rect(size)
      canvas.frame(@rect)
      title = TuiTui::DisplayText.new("pick a color: #{@cursor}  (drag title to move)")
      canvas.text(@rect.row + 1, @rect.col + 2, title.truncate(@rect.cols - 4), TITLE)
      COUNT.times { |i| draw_swatch(canvas, i) }
      canvas
    end

    private

    def frame_rect(size)
      width = (COLS * SW) + 4
      height = (COUNT / COLS) + 4
      return TuiTui::Rect.centered(size, cols: width, rows: height) unless @pos

      TuiTui::Rect.new(
        row: @pos[0].clamp(1, [size.rows - height + 1, 1].max),
        col: @pos[1].clamp(1, [size.cols - width + 1, 1].max),
        rows: height, cols: width
      )
    end

    def grid_top = @rect.row + 3
    def grid_left = @rect.col + 2

    def draw_swatch(canvas, index)
      row = grid_top + (index / COLS)
      col = grid_left + ((index % COLS) * SW)
      if index == @cursor
        canvas.text(row, col, "[]", TuiTui::Style.new(bg: index, fg: :bright_white))
      else
        canvas.text(row, col, "  ", TuiTui::Style.new(bg: index))
      end
    end

    def press(event)
      if on_title_bar?(event)
        @drag = [event.row - @rect.row, event.col - @rect.col] # pointer offset within the dialog
        nil
      else
        hit(event.row, event.col)
      end
    end

    def continue_drag(event)
      return nil unless @drag

      @pos = [event.row - @drag[0], event.col - @drag[1]] # keep the grab point under the pointer
      nil
    end

    def end_drag
      @drag = nil
      nil
    end

    # The top border + title row: grabbing here moves the dialog.
    def on_title_bar?(event)
      @rect && event.row.between?(@rect.row, @rect.row + 1) &&
        event.col.between?(@rect.col, @rect.col + @rect.cols - 1)
    end

    def move(delta)
      @cursor = (@cursor + delta).clamp(0, COUNT - 1)
      nil
    end

    def hit(row, col)
      grow = row - grid_top
      gcol = (col - grid_left) / SW
      return nil unless col >= grid_left && grow.between?(0, (COUNT / COLS) - 1) && gcol.between?(0, COLS - 1)

      (grow * COLS) + gcol
    end
  end

  class Paint
    def initialize
      @cells = {} # [row, col] => color index
      @color = 9  # bright red
      @brush = 1
      @rows = 24
      @modal = nil
      @picker_pos = nil # where the picker was last left, so it reopens in place
    end

    def update(event)
      case event
      when TuiTui::KeyEvent then @modal ? route(@modal.handle(event.key)) : handle_key(event.key)
      when TuiTui::MouseEvent then @modal ? route(@modal.handle_mouse(event)) : handle_mouse(event)
      else self
      end
    end

    def view(size)
      @rows = size.rows
      canvas = TuiTui::Canvas.blank(size)
      @cells.each do |(row, col), color|
        next unless row.between?(PAINT_TOP, size.rows) && col.between?(1, size.cols)

        canvas.text(row, col, " ", TuiTui::Style.new(bg: color))
      end
      draw_styles(canvas)
      draw_status(canvas, size)
      @modal&.draw(canvas, size)
      canvas
    end

    private

    # Resolve a modal result: an Integer is the picked color; :cancel keeps the
    # current one; nil means the dialog is still open.
    def route(result)
      return self if result.nil?

      @color = result if result.is_a?(Integer)
      @picker_pos = @modal.pos # remember where it was so the next open lands there
      @modal = nil
      self
    end

    def handle_key(key)
      case key
      when "q", TuiTui::KeyCode::CTRL_C then return :quit
      when "p" then @modal = ColorPicker.new(current: @color, pos: @picker_pos)
      when "c" then @cells = {}
      when "]" then @brush += 1
      when "[" then @brush = [@brush - 1, 1].max
      end
      self
    end

    def handle_mouse(event)
      return self unless %i[press drag].include?(event.action)

      if event.row == STATUS_ROW && (SWATCH_COL..SWATCH_COL + 1).cover?(event.col)
        @modal = ColorPicker.new(current: @color, pos: @picker_pos)
      elsif event.row >= PAINT_TOP
        stroke(event)
      end
      self
    end

    # Paint (or erase) a brush-sized square centered on the pointer.
    def stroke(event)
      top = event.row - ((@brush - 1) / 2)
      left = event.col - ((@brush - 1) / 2)
      @brush.times do |dr|
        @brush.times do |dc|
          row = top + dr
          col = left + dc
          next unless row.between?(PAINT_TOP, @rows) && col >= 1

          cell = [row, col]
          event.button == :right ? @cells.delete(cell) : @cells[cell] = @color
        end
      end
    end

    def draw_styles(canvas)
      spans = [TuiTui::Span["styles: ", DIM]]
      ATTRS.each { |attr| spans << TuiTui::Span[attr.to_s, TuiTui::Style.new(attrs: [attr])] << TuiTui::Span["  "] }
      canvas.line(STYLES_ROW, 1, spans) # Canvas advances the column per span
    end

    def draw_status(canvas, size)
      canvas.fill(TuiTui::Rect.new(row: STATUS_ROW, col: 1, rows: 1, cols: size.cols), BAR)
      canvas.text(STATUS_ROW, 1, " color: ", BAR)
      canvas.text(STATUS_ROW, SWATCH_COL, "  ", TuiTui::Style.new(bg: @color))
      hints = "  ##{@color}  brush #{@brush}  p=colors  [ ]=size  right-drag=erase  c=clear  q=quit"
      canvas.text(STATUS_ROW, SWATCH_COL + 2, TuiTui::DisplayText.new(hints).truncate(size.cols - SWATCH_COL - 1), BAR)
    end
  end
end

if $PROGRAM_NAME == __FILE__
  TuiTui::Runtime.new(PaintSample::Paint.new).run
end
