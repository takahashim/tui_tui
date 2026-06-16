# frozen_string_literal: true

require "spec_helper"

module TuiTui
  RSpec.describe Theme do
    it "DEFAULT provides a Style for every role" do
      d = Theme::DEFAULT
      %i[frame title text muted accent selection selection_dim bar cursor scroll_track scroll_thumb].each do |role|
        expect(d.public_send(role)).to be_a(Style)
      end
    end

    it "defaults use explicit colours, not theme-dependent reverse/dim" do
      # colour bar, not reverse
      expect(Theme::DEFAULT.selection.attrs).to eq([])
      # explicit colour, not dim
      expect(Theme::DEFAULT.frame.attrs).to eq([])
      # an explicit background
      expect(Theme::DEFAULT.selection.bg).not_to be_nil
    end

    it "derives a variant with Data#with, leaving other roles intact" do
      custom = Theme::DEFAULT.with(selection: Style.new(bg: :magenta))
      expect(custom.selection.bg).to eq(:magenta)
      # untouched roles preserved
      expect(custom.title).to eq(Theme::DEFAULT.title)
    end

    describe "presets" do
      it "exposes named sets that share readable greys but differ in hue/chrome" do
        expect(Theme::WARM).to be_a(Theme)
        expect(Theme::MONO).to be_a(Theme)
        # body text/muted stay neutral grey across presets (readability)
        expect(Theme::WARM.text).to eq(Theme::DEFAULT.text)
        expect(Theme::MONO.muted).to eq(Theme::DEFAULT.muted)
        # the visible chrome (frame, accent, selection) differs per preset
        expect(Theme::WARM.frame).not_to eq(Theme::DEFAULT.frame)
        expect(Theme::WARM.accent).not_to eq(Theme::DEFAULT.accent)
        expect(Theme::MONO.selection).not_to eq(Theme::DEFAULT.selection)
      end

      it "fetches a preset by name, falling back to DEFAULT" do
        expect(Theme.named(:warm)).to be(Theme::WARM)
        expect(Theme.named("mono")).to be(Theme::MONO)
        expect(Theme.named(:nonesuch)).to be(Theme::DEFAULT)
        expect(Theme.named(nil)).to be(Theme::DEFAULT)
      end
    end

    describe "background detection" do
      it "honours an explicit TUITUI_BACKGROUND override" do
        expect(Theme.detect_background(env: {"TUITUI_BACKGROUND" => "light"})).to eq(:light)
        expect(Theme.detect_background(env: {"TUITUI_BACKGROUND" => "DARK"})).to eq(:dark)
      end

      it "reads COLORFGBG (bg 15/7 = light), else assumes dark" do
        expect(Theme.detect_background(env: {"COLORFGBG" => "0;15"})).to eq(:light)
        expect(Theme.detect_background(env: {"COLORFGBG" => "15;0"})).to eq(:dark)
        expect(Theme.detect_background(env: {})).to eq(:dark)
      end

      it "Theme.auto returns the LIGHT or DARK cool theme for the background" do
        expect(Theme.auto(env: {"TUITUI_BACKGROUND" => "light"})).to be(Theme::LIGHT)
        expect(Theme.auto(env: {"TUITUI_BACKGROUND" => "dark"})).to be(Theme::DARK)
        # LIGHT really differs from DARK where it matters on a light terminal
        expect(Theme::LIGHT.muted).not_to eq(Theme::DARK.muted)
        expect(Theme::DARK).to be(Theme::DEFAULT)
      end
    end

    describe "light/dark alignment (every hue, both backgrounds)" do
      it "gives each hue a readable surface on both backgrounds" do
        %i[cool warm mono].each do |hue|
          dark = Theme.build(background: :dark, hue: hue)
          light = Theme.build(background: :light, hue: hue)
          # the body grey inverts with the background (so text stays readable)
          # light grey on dark
          expect(dark.muted).to eq(Theme::DARK.muted)
          # dark grey on light
          expect(light.muted).to eq(Theme::LIGHT.muted)
          expect(light.muted).not_to eq(dark.muted)
        end
      end

      it "auto applies the requested hue to the detected background" do
        light_warm = Theme.build(background: :light, hue: :warm)
        expect(Theme.auto(hue: :warm, env: {"TUITUI_BACKGROUND" => "light"})).to be(light_warm)
        expect(Theme.auto(hue: :mono, env: {"TUITUI_BACKGROUND" => "dark"})).to be(Theme::MONO)
      end
    end

    it "a widget honours an injected theme" do
      magenta = Theme::DEFAULT.with(selection: Style.new(fg: :black, bg: :magenta))
      select = Select.new("Pick", %w[a b c], default: 0, theme: magenta)
      canvas = Canvas.blank(Size.new(rows: 12, cols: 30))
      select.draw(canvas, Size.new(rows: 12, cols: 30))

      painted = (1..12).flat_map { |r| (1..30).map { |c| canvas.cell(r, c)&.style&.bg } }
      expect(painted).to include(:magenta)
    end
  end
end
