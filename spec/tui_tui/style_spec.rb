# frozen_string_literal: true

require "spec_helper"

module TuiTui
  # SGR emission across named / 256 / truecolor, plus the disabled and empty
  # short-circuits that keep rendered output snapshot-testable.
  RSpec.describe Style do
    it "emits a named foreground" do
      expect(Style.new(fg: :red).paint("x")).to eq("\e[31mx\e[0m")
    end

    it "shifts a named background by ten" do
      expect(Style.new(bg: :red).paint("x")).to eq("\e[41mx\e[0m")
    end

    it "puts attributes before color" do
      expect(Style.new(fg: :red, attrs: [:bold]).paint("x")).to eq("\e[1;31mx\e[0m")
    end

    it "supports bright colors" do
      expect(Style.new(fg: :bright_red).paint("x")).to eq("\e[91mx\e[0m")
    end

    it "treats an integer as a 256-color index" do
      expect(Style.new(fg: 200).paint("x")).to eq("\e[38;5;200mx\e[0m")
    end

    it "emits truecolor only at truecolor depth" do
      style = Style.new(fg: [10, 20, 30])
      expect(style.paint("x", depth: :truecolor)).to eq("\e[38;2;10;20;30mx\e[0m")
      # dropped, not garbled
      expect(style.paint("x", depth: :ansi256)).to eq("x")
    end

    it "returns plain text when disabled" do
      expect(Style.new(fg: :red, attrs: [:bold]).paint("x", enabled: false)).to eq("x")
    end

    it "passes text through for an empty style" do
      expect(Style.new.paint("x")).to eq("x")
    end

    it "emits no color at :none depth" do
      expect(Style.new(fg: :red, attrs: [:bold]).paint("x", depth: :none)).to eq("x")
    end

    it "downgrades a 256-color index to the nearest ANSI-16 at :basic16" do
      # 196 is the cube's pure red -> nearest 16 is bright red (91).
      expect(Style.new(fg: 196).paint("x", depth: :basic16)).to eq("\e[91mx\e[0m")
    end

    it "downgrades truecolor RGB to the nearest ANSI-16 at :basic16" do
      expect(Style.new(fg: [0, 0, 0]).paint("x", depth: :basic16)).to eq("\e[30mx\e[0m")
      expect(Style.new(bg: [255, 255, 255]).paint("x", depth: :basic16)).to eq("\e[107mx\e[0m")
    end

    it "still keeps named colors (and attrs) at :basic16" do
      expect(Style.new(fg: :red, attrs: [:bold]).paint("x", depth: :basic16)).to eq("\e[1;31mx\e[0m")
    end
  end
end
