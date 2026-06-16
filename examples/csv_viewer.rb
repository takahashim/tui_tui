#!/usr/bin/env ruby
# frozen_string_literal: true

# A small CSV viewer. It demonstrates a table-shaped app with a fixed header,
# vertical row selection, horizontal column navigation, width-aware cell
# clipping, and a status bar. Pass a CSV path, or run it without arguments to
# browse the built-in sample data.
#
#   ruby examples/csv_viewer.rb [CSV]
#
# Keys: j/k (or ↑/↓) move rows, h/l (or ←/→) move columns, Space page down,
# b page up, g/G top/bottom, 0/$ first/last column, q (or Ctrl-C) quit.

require "csv"
require_relative "../lib/tui_tui"

module CsvViewerSample
  SAMPLE = <<~CSV
    id,name,role,country,notes
    1,Ada Lovelace,Mathematician,United Kingdom,First programmer
    2,Grace Hopper,Computer Scientist,United States,Popularized machine-independent languages
    3,高橋,Engineer,日本,日本語のセルも幅安全に表示
    4,Margaret Hamilton,Software Engineer,United States,Apollo guidance software
    5,Katherine Johnson,Mathematician,United States,Orbital mechanics calculations
    6,Edsger Dijkstra,Computer Scientist,Netherlands,Shortest paths and structured programming
  CSV

  S = TuiTui::Style
  STYLE = {
    title: S.new(attrs: [:bold]),
    dim: S.new(attrs: [:dim]),
    header: S.new(fg: :bright_white, bg: 238, attrs: [:bold]),
    row_number: S.new(fg: :bright_black),
    selected_row: S.new(bg: 236),
    selected_cell: S.new(attrs: [:reverse, :bold]),
    status: S.new(attrs: [:reverse]),
    error: S.new(fg: :bright_red, attrs: [:bold]),
    accent: S.new(fg: :cyan, attrs: [:bold]),
  }.freeze

  ROW_NUMBER_WIDTH = 6
  MIN_COLUMN_WIDTH = 6
  MAX_COLUMN_WIDTH = 28

  class CsvViewer
    def initialize(path)
      @path = path
      @header, @rows, @error = load_csv(path)
      @list = TuiTui::ScrollList.new(@rows.size)
      @col = 0
      @left_col = 0
      @page = 1
      @widths = column_widths
    end

    def update(event)
      return self unless event.is_a?(TuiTui::KeyEvent)

      case event.key
      when "q", TuiTui::KeyCode::CTRL_C then return :quit
      when "j", :down then @list.move(1)
      when "k", :up then @list.move(-1)
      when " ", :pgdn then @list.move(@page)
      when "b", :pgup then @list.move(-@page)
      when "g", :home then @list.to_top
      when "G", :end then @list.to_end
      when "h", :left then move_col(-1)
      when "l", :right then move_col(1)
      when "0" then @col = 0
      when "$" then @col = last_col
      end
      self
    end

    def view(size)
      canvas = TuiTui::Canvas.blank(size)
      body, footer = split_footer(size)
      detail, status = footer.split_h(1)
      table = body

      @page = [table.rows - 1, 1].max
      @list.ensure_visible(@page)
      ensure_column_visible(table.cols - ROW_NUMBER_WIDTH)

      draw_table(canvas, table)
      draw_detail(canvas, detail)
      draw_status(canvas, status)
      canvas
    end

    private

    def load_csv(path)
      if path
        rows = CSV.read(path, headers: false)
        source = File.expand_path(path)
      else
        rows = CSV.parse(SAMPLE, headers: false)
        source = "(sample data)"
      end

      header = normalize_row(rows.shift || [])
      data = rows.map { |row| normalize_row(row) }
      width = [header.size, data.map(&:size).max || 0].max
      header = default_header(width) if header.empty?
      header = pad_row(header, width)
      data = data.map { |row| pad_row(row, width) }
      [header, data, nil]
    rescue CSV::MalformedCSVError, SystemCallError => e
      [["error"], [["#{e.class}: #{e.message}"]], "#{source || path}: #{e.message}"]
    end

    def normalize_row(row) = row.map { |cell| cell.to_s }
    def pad_row(row, width) = row + Array.new(width - row.size, "")
    def default_header(width) = Array.new(width) { |i| "column_#{i + 1}" }

    def split_footer(size)
      whole = TuiTui::Rect.new(row: 1, col: 1, rows: size.rows, cols: size.cols)
      return [whole, TuiTui::Rect.new(row: size.rows, col: 1, rows: 0, cols: size.cols)] if size.rows < 3

      whole.split_h(size.rows - 2)
    end

    def draw_table(canvas, rect)
      return if rect.rows <= 0 || rect.cols <= 0

      canvas.fill(TuiTui::Rect.new(row: rect.row, col: rect.col, rows: 1, cols: rect.cols), STYLE[:header])
      canvas.text(rect.row, rect.col, fit("#", ROW_NUMBER_WIDTH), STYLE[:header])
      each_visible_column(rect.cols - ROW_NUMBER_WIDTH) do |index, col, width|
        style = index == @col ? STYLE[:selected_cell] : STYLE[:header]
        canvas.text(rect.row, col, fit(@header[index], width), style)
      end

      if @rows.empty?
        canvas.text(rect.row + 1, rect.col + 1, "No rows", STYLE[:dim]) if rect.rows > 1
        return
      end

      @list.each_visible([rect.rows - 1, 0].max) do |row_index, offset|
        row = rect.row + 1 + offset
        selected = row_index == @list.cursor
        canvas.fill(TuiTui::Rect.new(row: row, col: rect.col, rows: 1, cols: rect.cols), STYLE[:selected_row]) if selected
        canvas.text(row, rect.col, fit((row_index + 1).to_s, ROW_NUMBER_WIDTH), selected ? STYLE[:selected_row] : STYLE[:row_number])
        each_visible_column(rect.cols - ROW_NUMBER_WIDTH) do |index, col, width|
          style = selected && index == @col ? STYLE[:selected_cell] : (selected ? STYLE[:selected_row] : nil)
          canvas.text(row, col, fit(@rows[row_index][index], width), style)
        end
      end
    end

    def draw_detail(canvas, rect)
      return if rect.rows <= 0

      canvas.hline(rect.row, rect.col, rect.cols, "-", STYLE[:dim])
      return if @rows.empty?

      label = @header[@col] || "column_#{@col + 1}"
      value = @rows[@list.cursor][@col].to_s
      text = "#{label}: #{value}"
      canvas.text(rect.row, rect.col + 1, TuiTui::DisplayText.new(text).truncate(rect.cols - 1), STYLE[:accent])
    end

    def draw_status(canvas, rect)
      return if rect.rows <= 0

      canvas.fill(rect, STYLE[:status])
      left = @error || " #{@path ? File.basename(@path) : "sample.csv"}"
      canvas.text(rect.row, rect.col, TuiTui::DisplayText.new(left).truncate(rect.cols), @error ? STYLE[:error] : STYLE[:status])

      right = " row #{@list.cursor + 1}/#{[@rows.size, 1].max}  col #{@col + 1}/#{@header.size}  j/k rows  h/l cols  q quit "
      width = TuiTui::DisplayText.new(right).width
      return if width >= rect.cols

      canvas.text(rect.row, rect.col + rect.cols - width, right, STYLE[:status])
    end

    def each_visible_column(available)
      return if available <= 0

      col = ROW_NUMBER_WIDTH + 1
      @left_col.upto(last_col) do |index|
        width = @widths[index]
        break if col + width - 1 > available + ROW_NUMBER_WIDTH

        yield index, col, width
        col += width
      end
    end

    def ensure_column_visible(available)
      return if available <= 0

      @left_col = @col if @col < @left_col
      while @col >= first_hidden_column(available)
        @left_col += 1
      end
      @left_col = @left_col.clamp(0, last_col)
    end

    def first_hidden_column(available)
      used = 0
      @left_col.upto(last_col) do |index|
        used += @widths[index]
        return index if used > available
      end
      last_col + 1
    end

    def move_col(delta)
      @col = (@col + delta).clamp(0, last_col)
    end

    def last_col = [@header.size - 1, 0].max

    def column_widths
      @header.each_index.map do |index|
        values = [@header[index], *@rows.first(200).map { |row| row[index] }]
        width = values.map { |value| TuiTui::DisplayText.new(value.to_s).width }.max || MIN_COLUMN_WIDTH
        (width + 2).clamp(MIN_COLUMN_WIDTH, MAX_COLUMN_WIDTH)
      end
    end

    def fit(value, width)
      text = TuiTui::DisplayText.new(" #{value}")
      text = text.truncate(width - 1) if text.width >= width
      text.to_s + (" " * [width - text.width, 0].max)
    end
  end
end

if $PROGRAM_NAME == __FILE__
  TuiTui::Runtime.new(CsvViewerSample::CsvViewer.new(ARGV[0])).run
end
