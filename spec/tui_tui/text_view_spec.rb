# frozen_string_literal: true

require "spec_helper"

module TuiTui
  RSpec.describe TextView do
    def rect(rows, cols) = Rect.new(row: 1, col: 1, rows: rows, cols: cols)

    it "draws the window of lines starting at top" do
      canvas = Canvas.new(2, 10)
      TextView.draw(canvas, rect(2, 10), %w[a b c d], top: 1)
      expect((1..2).map { |r| canvas.render_row(r, enabled: false).rstrip }).to eq(%w[b c])
    end

    it "truncates each line to the rect width" do
      canvas = Canvas.new(1, 4)
      TextView.draw(canvas, rect(1, 4), ["abcdef"])
      expect(canvas.render_row(1, enabled: false)).to eq("a...")
    end

    it "supports a lazy block (return nil to stop)" do
      canvas = Canvas.new(3, 6)
      TextView.draw(canvas, rect(3, 6), top: 5) { |i| i < 7 ? "L#{i}" : nil }
      shown = (1..3).map { |r| canvas.render_row(r, enabled: false).rstrip }
      # index 7 returned nil -> blank
      expect(shown).to eq(["L5", "L6", ""])
    end

    it "reserves a gutter and draws a scrollbar (total from the array)" do
      canvas = Canvas.new(3, 8)
      TextView.draw(canvas, rect(3, 8), (0..20).map { |i| "L#{i}" }, top: 0, scrollbar: Theme::DEFAULT)
      gutter = (1..3).map { |r| canvas.cell(r, 8).style }
      expect(gutter).to include(Theme::DEFAULT.scroll_track).or include(Theme::DEFAULT.scroll_thumb)
      # text beside the gutter
      expect(canvas.cell(1, 1).char).to eq("L")
    end

    it "uses the given total for the scrollbar with a lazy block" do
      canvas = Canvas.new(2, 6)
      TextView.draw(canvas, rect(2, 6), top: 0, scrollbar: Theme::DEFAULT, total: 50) { |i| "x#{i}" }
      expect((1..2).map { |r| canvas.cell(r, 6).style }).to include(Theme::DEFAULT.scroll_thumb)
    end

    it "draws styled Lines and arrays of Spans as given" do
      canvas = Canvas.new(1, 6)
      TextView.draw(canvas, rect(1, 6), [[Span["a", Style.new(fg: :red)], Span["b", Style.new(fg: :blue)]]])
      expect(canvas.cell(1, 1).style.fg).to eq(:red)
      expect(canvas.cell(1, 2).style.fg).to eq(:blue)
    end
  end
end
