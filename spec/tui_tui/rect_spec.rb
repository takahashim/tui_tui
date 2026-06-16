# frozen_string_literal: true

require "spec_helper"

module TuiTui
  RSpec.describe Rect do
    it "split h carves the top" do
      rect = Rect.new(row: 1, col: 1, rows: 24, cols: 80)

      top, bottom = rect.split_h(23)
      expect([top.row, top.col, top.rows, top.cols]).to eq([1, 1, 23, 80])
      expect([bottom.row, bottom.col, bottom.rows, bottom.cols]).to eq([24, 1, 1, 80])
    end

    it "split v carves the left" do
      rect = Rect.new(row: 1, col: 1, rows: 24, cols: 80)

      left, right = rect.split_v(40)
      expect([left.row, left.col, left.rows, left.cols]).to eq([1, 1, 24, 40])
      expect([right.row, right.col, right.rows, right.cols]).to eq([1, 41, 24, 40])
    end

    it "shift right leaves a gutter" do
      rect = Rect.new(row: 1, col: 1, rows: 24, cols: 80)

      shifted = rect.shift_right(1)
      expect(shifted.col).to eq(2)
      expect(shifted.cols).to eq(79)
    end

    describe "#split_ratio" do
      let(:rect) { Rect.new(row: 1, col: 1, rows: 10, cols: 100) }

      it "splits by the ratio" do
        left, right = rect.split_ratio(0.3)
        expect(left.cols).to eq(30)
        expect([right.col, right.cols]).to eq([31, 70])
      end

      it "leaves a gutter column between the panes" do
        left, right = rect.split_ratio(0.5, gutter: 1)
        expect(left.cols).to eq(50)
        # column 51 is the gutter
        expect(right.col).to eq(52)
        # 50 minus the gutter
        expect(right.cols).to eq(49)
      end

      it "clamps so neither side drops below min" do
        expect(rect.split_ratio(0.0, min: 12).first.cols).to eq(12)
        # cols - min
        expect(rect.split_ratio(1.0, min: 12).first.cols).to eq(88)
      end

      it "falls back to an even split when too narrow for min + gutter" do
        narrow = Rect.new(row: 1, col: 1, rows: 4, cols: 10)
        # hi(1) < lo(8)
        left, = narrow.split_ratio(0.2, min: 8, gutter: 1)
        expect(left.cols).to eq(5)
      end
    end
  end
end
