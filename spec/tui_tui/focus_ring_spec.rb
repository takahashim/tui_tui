# frozen_string_literal: true

require "spec_helper"

module TuiTui
  RSpec.describe FocusRing do
    it "starts on the first target" do
      expect(FocusRing.new(:a, :b).current).to eq(:a)
    end

    it "next advances and wraps around" do
      ring = FocusRing.new(:a, :b, :c)
      expect(ring.next.current).to eq(:b)
      expect(ring.next.next.current).to eq(:c)
      expect(ring.next.next.next.current).to eq(:a)
    end

    it "focused? reports the current target" do
      ring = FocusRing.new(:a, :b)
      expect(ring.focused?(:a)).to be(true)
      expect(ring.focused?(:b)).to be(false)
    end

    it "focus selects a member" do
      expect(FocusRing.new(:a, :b).focus(:b).current).to eq(:b)
    end

    it "focus ignores a non-member, returning itself unchanged" do
      ring = FocusRing.new(:a, :b)
      expect(ring.focus(:nope)).to equal(ring)
    end

    it "is immutable — next returns a new ring" do
      ring = FocusRing.new(:a, :b)
      ring.next
      expect(ring.current).to eq(:a)
    end

    it "raises with no targets" do
      expect { FocusRing.new }.to raise_error(ArgumentError)
    end
  end
end
