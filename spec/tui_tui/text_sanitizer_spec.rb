# frozen_string_literal: true

require "spec_helper"

module TuiTui
  RSpec.describe TextSanitizer do
    it "returns a valid string unchanged (same object)" do
      string = "hello 日本語"
      expect(described_class.sanitize(string)).to be(string)
    end

    it "scrubs invalid byte sequences to '?'" do
      malformed = "ab\xFFcd".b.force_encoding("UTF-8")

      result = described_class.sanitize(malformed)
      expect(result).to eq("ab?cd")
      expect(result).to be_valid_encoding
    end

    it "judges validity against the string's own encoding (not just UTF-8)" do
      sjis = "日本".encode("Shift_JIS")

      # valid Shift_JIS -> untouched
      expect(described_class.sanitize(sjis)).to be(sjis)
    end

    describe ".printable?" do
      it "accepts ordinary text, including multibyte UTF-8" do
        expect(described_class.printable?("hello")).to be(true)
        expect(described_class.printable?("日本語")).to be(true)
      end

      it "rejects C0 control bytes and DEL" do
        expect(described_class.printable?("a\tb")).to be(false)
        expect(described_class.printable?("\e")).to be(false)
        expect(described_class.printable?("\x7F")).to be(false)
      end
    end
  end
end
