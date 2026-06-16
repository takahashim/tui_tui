# frozen_string_literal: true

require "spec_helper"

module TuiTui
  RSpec.describe Palette do
    describe ".rgb_from_256" do
      it "returns ANSI-16 rgb for low indices" do
        palette = Palette.new

        expect(palette.rgb_from_256(0)).to eq([0, 0, 0])
        expect(palette.rgb_from_256(15)).to eq([255, 255, 255])
      end

      it "maps the 6x6x6 cube" do
        palette = Palette.new

        # cube origin
        expect(palette.rgb_from_256(16)).to eq([0, 0, 0])
        # cube max
        expect(palette.rgb_from_256(231)).to eq([255, 255, 255])
        # pure red
        expect(palette.rgb_from_256(196)).to eq([255, 0, 0])
      end

      it "maps the grayscale ramp" do
        palette = Palette.new

        expect(palette.rgb_from_256(232)).to eq([8, 8, 8])
        expect(palette.rgb_from_256(255)).to eq([238, 238, 238])
      end
    end

    describe ".nearest_code" do
      it "returns the base SGR code of the closest ANSI-16 color" do
        palette = Palette.new

        # black
        expect(palette.nearest_code([0, 0, 0])).to eq(30)
        # bright red
        expect(palette.nearest_code([255, 0, 0])).to eq(91)
        # bright white
        expect(palette.nearest_code([255, 255, 255])).to eq(97)
        # near-black
        expect(palette.nearest_code([10, 10, 10])).to eq(30)
      end
    end
  end
end
