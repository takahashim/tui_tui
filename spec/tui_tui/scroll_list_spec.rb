# frozen_string_literal: true

require "spec_helper"

module TuiTui
  RSpec.describe ScrollList do
    it "moves and clamps the cursor" do
      list = ScrollList.new(3)
      expect(list.cursor).to eq(0)
      list.move(1)
      expect(list.cursor).to eq(1)
      list.move(5)
      # clamped to last
      expect(list.cursor).to eq(2)
      list.move(-9)
      expect(list.cursor).to eq(0)
    end

    it "to top and end" do
      list = ScrollList.new(10)
      list.to_end
      expect(list.cursor).to eq(9)
      expect(list.at_end?).to be_truthy
      list.to_top
      expect(list.cursor).to eq(0)
    end

    it "empty list" do
      list = ScrollList.new(0)
      expect(list.empty?).to be_truthy
      expect(list.last).to eq(0)
      list.move(1)
      expect(list.cursor).to eq(0)
    end

    it "count change clamps cursor" do
      list = ScrollList.new(10)
      list.to_end
      list.count = 4
      # was 9, clamped to new last
      expect(list.cursor).to eq(3)
      expect(list.count).to eq(4)
    end

    it "ensure visible scrolls the window" do
      list = ScrollList.new(100)
      list.go_to(20).ensure_visible(10)
      # cursor at 20, window of 10 -> top 11
      expect(list.top).to eq(11)
      list.go_to(5).ensure_visible(10)
      # scrolled back up to keep cursor visible
      expect(list.top).to eq(5)
    end

    it "each visible yields window" do
      list = ScrollList.new(100)
      list.go_to(25).ensure_visible(5)
      seen = list.each_visible(5).to_a
      expect(seen).to eq([[21, 0], [22, 1], [23, 2], [24, 3], [25, 4]])
    end

    it "each visible stops at end" do
      list = ScrollList.new(3)
      seen = list.each_visible(10).map { |index, _offset| index }
      # only three items, not ten rows
      expect(seen).to eq([0, 1, 2])
    end
  end
end
