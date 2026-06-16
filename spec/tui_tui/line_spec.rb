# frozen_string_literal: true

require "spec_helper"

module TuiTui
  RSpec.describe Line do
    let(:s1) { Style.new(fg: :red) }
    let(:s2) { Style.new(fg: :blue) }

    it "sums span widths, counting wide characters as two" do
      line = Line[Span["ab", s1], Span["あ", s2]]
      expect(line.width).to eq(4)
      expect(line.to_s).to eq("abあ")
    end

    it "returns itself unchanged when it already fits" do
      line = Line[Span["ab", s1]]
      expect(line.truncate(10)).to be(line)
    end

    describe "#truncate (style-preserving)" do
      it "keeps whole spans, cuts the boundary span, and appends the marker in its style" do
        # width 6
        line = Line[Span["ab", s1], Span["cdef", s2]]
        # budget 3 (marker reserves 1)
        result = line.truncate(4, marker: ".")

        expect(result.to_s).to eq("abc.")
        expect(result.width).to be <= 4
        # marker takes the cut span's style
        expect(result.spans.map(&:style)).to eq([s1, s2, s2])
      end

      it "never splits a wide glyph at the cut" do
        # widths 1,2,2 = 5
        line = Line[Span["aあい", s1]]
        # budget 4: "a"(1)+"あ"(2)=3, "い" would overflow
        result = line.truncate(4, marker: "")

        expect(result.to_s).to eq("aあ")
        expect(result.width).to eq(3)
      end

      it "degrades to a truncated marker (keeping the first span's style) when there is no room" do
        line = Line[Span["abcdef", s1]]
        result = line.truncate(2, marker: "...")
        expect(result.to_s).to eq("..")
        # style preserved, not dropped to nil
        expect(result.spans.first.style).to eq(s1)
      end
    end
  end
end
