# frozen_string_literal: true

require "spec_helper"

module TuiTui
  RSpec.describe Fuzzy do
    it "matches a subsequence and reports positions" do
      m = Fuzzy.new("ac").match("abc")
      expect(m.positions).to eq([0, 2])
      expect(m.score).to be > 0
    end

    it "is case-insensitive" do
      expect(Fuzzy.new("FB").match("file_browser").positions).to eq([0, 5])
    end

    it "reports grapheme indices, not codepoint indices" do
      # "é" is e + combining acute (2 codepoints, 1 grapheme); "x" is grapheme 1.
      expect(Fuzzy.new("x").match("éx").positions).to eq([1])
      # a query grapheme that is itself multi-codepoint matches as one unit
      expect(Fuzzy.new("é").match("aéb").positions).to eq([1])
    end

    it "returns nil when a query character is missing" do
      expect(Fuzzy.new("xz").match("abc")).to be_nil
    end

    it "treats an empty query as matching everything" do
      m = Fuzzy.new("").match("anything")
      expect(m.positions).to eq([])
      expect(m.score).to eq(0)
    end

    it "rank keeps matches, best first, and drops non-matches" do
      ranked = Fuzzy.new("fb").rank(%w[foobar file_browser zzz])
      # word-boundary "fb" wins
      expect(ranked.map(&:first)).to eq(%w[file_browser foobar])
    end

    it "prefers a contiguous match over a spread-out one" do
      fuzzy = Fuzzy.new("ab")
      # a,b adjacent (no leading boundary on either)
      contiguous = fuzzy.match("xab").score
      # a..b apart
      spread = fuzzy.match("xaxb").score
      expect(contiguous).to be > spread
    end

    it "rank can match on a derived string via a block" do
      item = Struct.new(:name).new("file_browser")
      ranked = Fuzzy.new("fb").rank([item]) { |it| it.name }
      expect(ranked.first.first).to eq(item)
    end
  end
end
