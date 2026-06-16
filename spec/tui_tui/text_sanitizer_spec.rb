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
  end
end
