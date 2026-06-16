# frozen_string_literal: true

require "spec_helper"

module TuiTui
  RSpec.describe List do
    def rect(rows, cols) = Rect.new(row: 1, col: 1, rows: rows, cols: cols)

    it "draws only the visible window, scrolled to keep the cursor in view" do
      # cursor at the last of 10 items
      scroll = ScrollList.new(10).go_to(9)
      canvas = Canvas.new(3, 8)

      List.new(scroll).draw(canvas, rect(3, 8)) { |index, _sel| Line[Span["item#{index}"]] }

      shown = (1..3).map { |r| canvas.render_row(r, enabled: false).rstrip }
      # scrolled so item9 (cursor) shows
      expect(shown).to eq(%w[item7 item8 item9])
    end

    it "fills the cursor row with the highlight style, leaving others alone" do
      scroll = ScrollList.new(3).go_to(1)
      canvas = Canvas.new(3, 6)
      hi = Style.new(attrs: [:reverse])

      List.new(scroll).draw(canvas, rect(3, 6), highlight: hi) do |index, selected|
        Line[Span["r#{index}", selected ? hi : nil]]
      end

      # cursor row, drawn text
      expect(canvas.cell(2, 1).style).to eq(hi)
      # cursor row, blank cell from the full-width fill
      expect(canvas.cell(2, 6).style).to eq(hi)
      # non-cursor row not filled
      expect(canvas.cell(1, 6).style).to be_nil
    end

    it "truncates each row to the rect width" do
      canvas = Canvas.new(1, 4)

      List.new(ScrollList.new(1)).draw(canvas, rect(1, 4)) { |_index, _sel| Line[Span["abcdef"]] }

      # default marker reserves width
      expect(canvas.render_row(1, enabled: false)).to eq("a...")
    end

    it "draws a scrollbar in a reserved gutter when given a theme" do
      # 20 items, plenty to scroll
      scroll = ScrollList.new(20).go_to(0)
      canvas = Canvas.new(4, 8)

      List.new(scroll).draw(canvas, rect(4, 8), scrollbar: Theme::DEFAULT) { |i, _s| Line[Span["item#{i}"]] }

      # the last column is the scrollbar gutter; text occupies cols 1..7
      gutter_styles = (1..4).map { |r| canvas.cell(r, 8).style }
      expect(gutter_styles).to include(Theme::DEFAULT.scroll_track).or include(Theme::DEFAULT.scroll_thumb)
      # list text still starts at col 1
      expect(canvas.cell(1, 1).char).to eq("i")
    end

    it "accepts a bare array of spans as row content" do
      canvas = Canvas.new(1, 10)

      List.new(ScrollList.new(1)).draw(canvas, rect(1, 10)) do |_index, _sel|
        [Span["a", Style.new(fg: :red)], Span["b", Style.new(fg: :blue)]]
      end

      expect(canvas.cell(1, 1).style.fg).to eq(:red)
      expect(canvas.cell(1, 2).style.fg).to eq(:blue)
    end
  end
end
