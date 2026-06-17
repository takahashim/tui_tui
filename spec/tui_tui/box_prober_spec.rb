# frozen_string_literal: true

require "spec_helper"
require "stringio"

module TuiTui
  RSpec.describe BoxProber do
    # The prober reads char-by-char from a StringIO; `wait` is stubbed so it never
    # blocks on a real fd.
    def measure(reply, **opts)
      out = StringIO.new
      total = described_class
        .new(wait: ->(_io, _t) { true }, **opts)
        .measure_all(input: StringIO.new(reply), output: out)
      [total, out.string]
    end

    it "returns the advance (cols - 1) for a width-1 reply" do
      total, written = measure("\e[1;12R")
      # 11 glyphs, started at column 1 -> cursor at column 12 -> advance 11
      expect(total).to eq(11)
      expect(written).to include(BoxChrome::PROBE_GLYPHS)
      expect(written).to include("\e[6n")
      expect(written).to end_with("\r\e[K")
    end

    it "reports the larger advance when glyphs render double-width" do
      total, = measure("\e[1;23R")
      expect(total).to eq(22)
    end

    it "parses a CPR that follows leading garbage" do
      total, = measure("garbage\e[1;12R")
      expect(total).to eq(11)
    end

    it "returns -1 on timeout / no reply" do
      out = StringIO.new
      total = described_class
        .new(wait: ->(_io, _t) { false })
        .measure_all(input: StringIO.new(""), output: out)
      expect(total).to eq(-1)
    end

    it "returns -1 when the reply is unparseable junk past the cap" do
      total, = measure("x" * 100)
      expect(total).to eq(-1)
    end
  end
end
