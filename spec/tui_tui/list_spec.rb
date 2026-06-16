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

    describe "scrollbar auto:" do
      it "hides the gutter when items fit the rect" do
        canvas = Canvas.new(4, 8)
        List.new(ScrollList.new(3)).draw(canvas, rect(4, 8), scrollbar: Theme::DEFAULT, auto: true) do |i, _s|
          Line[Span["item#{i}"]]
        end
        expect(canvas.cell(1, 8).style).to be_nil
      end

      it "shows the gutter when items overflow the rect" do
        canvas = Canvas.new(4, 8)
        List.new(ScrollList.new(20)).draw(canvas, rect(4, 8), scrollbar: Theme::DEFAULT, auto: true) do |i, _s|
          Line[Span["item#{i}"]]
        end
        gutter = (1..4).map { |r| canvas.cell(r, 8).style }
        expect(gutter).to include(Theme::DEFAULT.scroll_track).or include(Theme::DEFAULT.scroll_thumb)
      end
    end

    describe "#index_at" do
      def press(row, col) = MouseEvent.new(action: :press, button: :left, row: row, col: col)

      it "maps a click row to the scrolled index" do
        scroll = ScrollList.new(10).go_to(9) # scrolled so top is 7 for a 3-row body
        list = List.new(scroll)
        r = rect(3, 8)
        # render to settle @scroll.top against the body height
        list.draw(Canvas.new(3, 8), r) { |i, _s| Line[Span["item#{i}"]] }

        expect(list.index_at(r, press(1, 1))).to eq(7)
        expect(list.index_at(r, press(3, 4))).to eq(9)
      end

      it "returns nil outside the body and below the last item" do
        scroll = ScrollList.new(2)
        list = List.new(scroll)
        r = rect(5, 8)

        expect(list.index_at(r, press(9, 1))).to be_nil # outside the rect
        expect(list.index_at(r, press(3, 1))).to be_nil # empty row below the 2 items
      end

      it "excludes the scrollbar gutter column when scrollbar is given" do
        scroll = ScrollList.new(20)
        list = List.new(scroll)
        r = rect(4, 8)

        expect(list.index_at(r, press(1, 8), scrollbar: Theme::DEFAULT)).to be_nil # gutter col
        expect(list.index_at(r, press(1, 7), scrollbar: Theme::DEFAULT)).to eq(0)  # last body col
      end
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
