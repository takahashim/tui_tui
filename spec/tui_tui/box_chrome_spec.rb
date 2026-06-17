# frozen_string_literal: true

require "spec_helper"
require "stringio"

module TuiTui
  RSpec.describe BoxChrome do
    describe ".from" do
      it "maps override strings, else :auto" do
        expect(described_class.from("ascii")).to be(BoxChrome::ASCII)
        expect(described_class.from("off")).to be(BoxChrome::ASCII)
        expect(described_class.from("unicode")).to be(BoxChrome::UNICODE)
        expect(described_class.from("on")).to be(BoxChrome::UNICODE)
        expect(described_class.from("")).to eq(:auto)
        expect(described_class.from("auto")).to eq(:auto)
      end
    end

    describe ".supported?" do
      it "requires every probed glyph to render at width 1" do
        expect(described_class.supported?(BoxChrome::PROBE_GLYPHS.length)).to be(true)
        expect(described_class.supported?(BoxChrome::PROBE_GLYPHS.length + 1)).to be(false)
        expect(described_class.supported?(-1)).to be(false)
      end
    end

    describe ".resolve" do
      let(:io) { StringIO.new }
      let(:ok_prober) { double(measure_all: BoxChrome::PROBE_GLYPHS.length) }
      let(:wide_prober) { double(measure_all: BoxChrome::PROBE_GLYPHS.length * 2) }

      it "uses UNICODE when the probe proves width 1" do
        chrome = described_class.resolve(input: io, output: io, term_cols: 80, env: {}, prober: ok_prober)
        expect(chrome).to be(BoxChrome::UNICODE)
      end

      it "falls back to ASCII when the probe reports double width" do
        chrome = described_class.resolve(input: io, output: io, term_cols: 80, env: {}, prober: wide_prober)
        expect(chrome).to be(BoxChrome::ASCII)
      end

      it "honors TUITUI_BOX=ascii without probing" do
        prober = double
        expect(prober).not_to receive(:measure_all)
        chrome = described_class.resolve(input: io, output: io, term_cols: 80, env: {"TUITUI_BOX" => "ascii"}, prober: prober)
        expect(chrome).to be(BoxChrome::ASCII)
      end

      it "honors TUITUI_BOX=unicode without probing" do
        prober = double
        expect(prober).not_to receive(:measure_all)
        chrome = described_class.resolve(input: io, output: io, term_cols: 80, env: {"TUITUI_BOX" => "unicode"}, prober: prober)
        expect(chrome).to be(BoxChrome::UNICODE)
      end

      it "falls back to ASCII without probing on a too-narrow terminal" do
        prober = double
        expect(prober).not_to receive(:measure_all)
        chrome = described_class.resolve(input: io, output: io, term_cols: 8, env: {}, prober: prober)
        expect(chrome).to be(BoxChrome::ASCII)
      end
    end
  end
end
