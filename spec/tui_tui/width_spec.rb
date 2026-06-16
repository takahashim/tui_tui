# frozen_string_literal: true

require "spec_helper"

module TuiTui
  # Column-width accounting for ASCII, East Asian Wide/Fullwidth, zero-width
  # marks, and the DisplayText helpers built on them.
  RSpec.describe DisplayText do
    it "ascii is one column each" do
      expect(DisplayText.new("abc").width).to eq(3)
      expect(Width.char("A")).to eq(1)
    end

    it "japanese is two columns each" do
      expect(DisplayText.new("あいう").width).to eq(6)
      expect(Width.char("あ")).to eq(2)
      expect(Width.char("漢")).to eq(2)
      expect(Width.char("ア")).to eq(2)
    end

    it "emoji" do
      expect(DisplayText.new("😇").width).to eq(2)
      expect(DisplayText.new("🚀").width).to eq(2)
    end

    it "emoji with variation selector stays two" do
      # base emoji + VS16 (zero-width)
      expect(DisplayText.new("👍️").width).to eq(2)
    end

    it "emoji skin tone modifier is zero width" do
      # thumbs-up + medium skin tone: 2 + 0
      expect(DisplayText.new("👍🏽").width).to eq(2)
    end

    it "fullwidth forms are wide" do
      # U+FF21 fullwidth A
      expect(Width.char("Ａ")).to eq(2)
      # U+FF01 fullwidth exclamation
      expect(Width.char("！")).to eq(2)
    end

    it "mixed ascii and wide" do
      # 1 + 1(space) + 2
      expect(DisplayText.new("a あ").width).to eq(4)
    end

    it "combining mark is zero width" do
      # combining acute accent
      expect(Width.char("́")).to eq(0)
      # "e" + combining = one column
      expect(DisplayText.new("é").width).to eq(1)
    end

    it "control characters are zero width" do
      expect(Width.char("\t")).to eq(0)
      expect(Width.char("\e")).to eq(0)
    end

    it "space is a normal column" do
      expect(Width.char(" ")).to eq(1)
    end

    it "supplementary ideograph is wide" do
      # CJK Ext B
      expect(Width.char("\u{20000}")).to eq(2)
    end

    it "truncate returns string when it fits" do
      expect(DisplayText.new("abc").truncate(5).to_s).to eq("abc")
      expect(DisplayText.new("あい").truncate(4).to_s).to eq("あい")
    end

    it "truncate clips ascii with marker" do
      expect(DisplayText.new("abcdef").truncate(5).to_s).to eq("ab...")
    end

    it "truncate respects wide boundaries" do
      # max 4, empty marker: two wide chars fit exactly.
      expect(DisplayText.new("あいうえ").truncate(4, marker: "").to_s).to eq("あい")
      # a wide char must not be split across the budget.
      expect(DisplayText.new("あいうえ").truncate(3, marker: "").to_s).to eq("あ")
    end

    it "truncate zero max is empty" do
      expect(DisplayText.new("abc").truncate(0).to_s).to eq("")
    end

    it "center pads both sides to the target width" do
      expect(DisplayText.new("ab").center(6).to_s).to eq("  ab  ")
      # odd gap: extra space on the right
      expect(DisplayText.new("ab").center(5).to_s).to eq(" ab  ")
      # wide char counts as 2
      expect(DisplayText.new("あ").center(4).to_s).to eq(" あ ")
    end

    it "center leaves text at or beyond the width untouched" do
      expect(DisplayText.new("abcdef").center(3).to_s).to eq("abcdef")
    end

    it "wrap returns single line when it fits" do
      expect(DisplayText.new("abc").wrap(10).map(&:to_s)).to eq(["abc"])
      expect(DisplayText.new("").wrap(10).map(&:to_s)).to eq([""])
    end

    it "wrap breaks long lines to width" do
      expect(DisplayText.new("abcdefghijk").wrap(5).map(&:to_s)).to eq(%w[abcde fghij k])
    end

    it "wrap indents continuation lines within budget" do
      # max 6, indent "  " (2) -> first line 6 cols, continuations 4 cols + indent.
      expect(DisplayText.new("abcdefghijk").wrap(6, indent: "  ").map(&:to_s)).to eq(["abcdef", "  ghij", "  k"])
    end

    it "wrap does not split a wide char across lines" do
      # Each kanji is 2 cols; at max 3 only one fits per line.
      expect(DisplayText.new("あいう").wrap(3).map(&:to_s)).to eq(%w[あ い う])
    end

    it "scrubs invalid utf-8 for display" do
      expect(DisplayText.new("a\xE3b").to_s).to eq("a?b")
    end
  end
end
