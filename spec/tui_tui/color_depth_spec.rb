# frozen_string_literal: true

require "spec_helper"

module TuiTui
  RSpec.describe ColorDepth do
    describe ".detect" do
      it "detects truecolor from COLORTERM" do
        expect(ColorDepth.detect("TERM" => "xterm-256color", "COLORTERM" => "truecolor")).to eq(:truecolor)
        expect(ColorDepth.detect("TERM" => "xterm-256color", "COLORTERM" => "24bit")).to eq(:truecolor)
      end

      it "defaults to 256 on a normal terminal" do
        expect(ColorDepth.detect("TERM" => "xterm-256color")).to eq(:ansi256)
        expect(ColorDepth.detect("TERM" => "xterm-256color", "COLORTERM" => "")).to eq(:ansi256)
      end

      it "disables color when NO_COLOR is present (any value)" do
        expect(ColorDepth.detect("TERM" => "xterm-256color", "NO_COLOR" => "1")).to eq(:none)
        expect(ColorDepth.detect("TERM" => "xterm-256color", "NO_COLOR" => "")).to eq(:none)
        # NO_COLOR wins even over COLORTERM
        expect(ColorDepth.detect("TERM" => "xterm-256color", "NO_COLOR" => "1", "COLORTERM" => "truecolor")).to(
          eq(:none)
        )
      end

      it "disables color for a dumb or absent TERM" do
        expect(ColorDepth.detect("TERM" => "dumb")).to eq(:none)
        expect(ColorDepth.detect("TERM" => "")).to eq(:none)
        expect(ColorDepth.detect({})).to eq(:none)
      end
    end

    describe ".from" do
      it "maps explicit override names to depths" do
        expect(ColorDepth.from("none")).to eq(:none)
        expect(ColorDepth.from("16")).to eq(:basic16)
        expect(ColorDepth.from("basic")).to eq(:basic16)
        expect(ColorDepth.from("256")).to eq(:ansi256)
        expect(ColorDepth.from("truecolor")).to eq(:truecolor)
      end

      it "falls back to detection for auto/blank/unknown" do
        expect(ColorDepth.from("auto", "TERM" => "xterm-256color")).to eq(:ansi256)
        expect(ColorDepth.from("", "TERM" => "xterm-256color")).to eq(:ansi256)
        expect(ColorDepth.from("bogus", "TERM" => "xterm-256color", "COLORTERM" => "truecolor")).to eq(:truecolor)
      end
    end
  end
end
