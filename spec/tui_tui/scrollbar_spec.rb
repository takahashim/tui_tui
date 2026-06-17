# frozen_string_literal: true

require "spec_helper"

module TuiTui
  RSpec.describe Scrollbar do
    describe ".geometry" do
      it "shows no thumb (track only) when everything is visible" do
        # total <= visible
        expect(described_class.geometry(10, 0, 10, 8)).to eq([0, 0])
        expect(described_class.geometry(10, 0, 5, 5)).to eq([0, 0])
      end

      it "sizes the thumb proportionally and places it by scroll position" do
        # 10-row track, 5 of 10 visible -> half-height thumb (5 rows)
        # at top
        expect(described_class.geometry(10, 0, 5, 10)).to eq([5, 0])
        # scrolled to bottom
        expect(described_class.geometry(10, 5, 5, 10)).to eq([5, 5])
      end

      it "keeps a minimum thumb of one row and clamps to the track" do
        # huge list
        length, offset = described_class.geometry(4, 999, 2, 1000)
        expect(length).to eq(1)
        # clamped to the last row
        expect(offset).to eq(3)
      end
    end

    it "draws a track with a reverse thumb over the gutter" do
      canvas = Canvas.new(4, 1)
      # 8 items, window of 4, at top -> thumb length 2 at offset 0
      Scrollbar.draw(canvas, Rect.new(row: 1, col: 1, rows: 4, cols: 1), top: 0, visible: 4, total: 8)

      # thumb
      expect(canvas.cell(1, 1).style).to eq(Scrollbar::THUMB)
      expect(canvas.cell(2, 1).style).to eq(Scrollbar::THUMB)
      # track
      expect(canvas.cell(3, 1).char).to eq("|")
      expect(canvas.cell(3, 1).style).to eq(Scrollbar::TRACK)
    end

    it "draws the track with the canvas's chrome glyph" do
      canvas = Canvas.new(4, 1, chrome: BoxChrome::UNICODE)
      Scrollbar.draw(canvas, Rect.new(row: 1, col: 1, rows: 4, cols: 1), top: 0, visible: 4, total: 8)

      expect(canvas.cell(3, 1).char).to eq("│")
    end
  end
end
