# frozen_string_literal: true

require "spec_helper"
require "stringio"

module TuiTui
  # Properties the renderer must hold for *any* input — including hostile content
  # (raw escape sequences) and awkward Unicode (wide, combining, ZWJ, flags).
  # Each property is checked over a curated corpus plus a seeded fuzz sweep, so a
  # whole class of regressions (misalignment, terminal injection) is caught at
  # once rather than case by case.
  RSpec.describe "render invariants" do
    # A grab-bag of the cases that have historically broken cell grids.
    CORPUS = [
      "",
      "hello world",
      # wide
      "あいうえお",
      # mixed narrow/wide
      "a あ b",
      # e + combining acute (one grapheme)
      "café",
      # emoji
      "😇🚀",
      # ZWJ family (one grapheme)
      "👨‍👩‍👧",
      # flag (regional-indicator pair)
      "🇯🇵",
      # emoji + skin-tone modifier
      "👍🏽",
      # raw SGR injection attempt
      "\e[31mRED\e[0m",
      # assorted C0 controls inline
      "a\eb\tc\rd",
      # combining mark with no base
      "́leading mark",
      # far wider than any terminal
      "x" * 500,
      "あ" * 500,
      # invalid UTF-8 (stray lead byte)
      "bad\xE3byte",
      # all-invalid bytes
      "\xFF\xFE".b
    ].freeze

    # Deterministic fuzz: random strings from a pool of the interesting glyphs.
    POOL = %W[a Z 0 " " あ 漢 😇 👍 ́ \e \t \r \n 🇯 🇵 ! Ａ].freeze

    describe "a drawn row always fills exactly its width" do
      [1, 5, 20, 80].each do |cols|
        it "holds for the corpus at #{cols} columns" do
          draw = -> (string) {
            Canvas.new(1, cols).tap { |canvas| canvas.text(1, 1, string) }.render_row(1, enabled: false)
          }

          CORPUS.each do |s|
            expect(DisplayText.new(draw.call(s)).width).to eq(cols), "#{s.inspect} @ #{cols} cols"
          end
        end
      end

      it "holds under a fuzz sweep" do
        rng = Random.new(1234)
        strings = Array.new(300) { Array.new(rng.rand(0..40)) { POOL[rng.rand(POOL.length)] }.join }

        strings.each do |s|
          [1, 7, 24, 64].each do |cols|
            canvas = Canvas.new(1, cols)
            canvas.text(1, 1, s)

            expect(DisplayText.new(canvas.render_row(1, enabled: false)).width).to(
              eq(cols),
              "#{s.inspect} @ #{cols} cols"
            )
          end
        end
      end
    end

    describe "the sink tolerates invalid UTF-8" do
      it "never raises and stays exactly the requested width" do
        ["bad\xE3byte", "\xFF\xFE".b, "\xE3", "ok\xC0\xC0"].each do |s|
          canvas = Canvas.new(1, 20)
          expect { canvas.text(1, 1, s) }.not_to raise_error
          expect(DisplayText.new(canvas.render_row(1, enabled: false)).width).to eq(20)
        end
      end

      it "measures and truncates invalid UTF-8 without raising" do
        expect { DisplayText.new("a\xE3b").width }.not_to raise_error
        expect { DisplayText.new("a\xE3b\xFF").truncate(3) }.not_to raise_error
        expect { DisplayText.new("a\xE3b\xFF").wrap(2) }.not_to raise_error
      end
    end

    describe "a drawn row never emits a raw control byte" do
      it "neutralizes every control character (no terminal injection)" do
        rng = Random.new(9876)
        strings = Array.new(300) { Array.new(rng.rand(0..40)) { POOL[rng.rand(POOL.length)] }.join }

        (CORPUS + strings).each do |s|
          canvas = Canvas.new(1, 40)
          canvas.text(1, 1, s)
          out = canvas.render_row(1, enabled: false)
          offenders = out.each_char.select { |c| Width.control?(c.ord) }
          expect(offenders).to be_empty, "leaked #{offenders.inspect} from #{s.inspect}"
        end
      end
    end

    describe "Width helpers stay within budget" do
      it "truncate with no marker always fits the width" do
        rng = Random.new(555)
        strings = Array.new(200) { Array.new(rng.rand(0..40)) { POOL[rng.rand(POOL.length)] }.join }

        (CORPUS + strings).each do |s|
          [0, 1, 2, 3, 10, 30].each do |max|
            truncated = DisplayText.new(s).truncate(max, marker: "")
            expect(DisplayText.new(truncated).width).to be <= max, "#{s.inspect} @ #{max}"
          end
        end
      end

      # The default "..." marker is itself 3 columns, so it can only be honored
      # once the budget can hold it; real callers truncate to pane widths >> 3.
      it "truncate with the default marker fits whenever the marker can" do
        rng = Random.new(555)
        strings = Array.new(200) { Array.new(rng.rand(0..40)) { POOL[rng.rand(POOL.length)] }.join }

        (CORPUS + strings).each do |s|
          [3, 10, 30].each do |max|
            truncated = DisplayText.new(s).truncate(max)
            expect(DisplayText.new(truncated).width).to be <= max, "#{s.inspect} @ #{max}"
          end
        end
      end

      it "center reaches exactly the target width (or leaves overlong text alone)" do
        rng = Random.new(777)
        strings = Array.new(200) { Array.new(rng.rand(0..40)) { POOL[rng.rand(POOL.length)] }.join }

        (CORPUS + strings).each do |s|
          [0, 5, 20, 60].each do |width|
            text = DisplayText.new(s)
            expect(DisplayText.new(text.center(width)).width).to eq([text.width, width].max)
          end
        end
      end

      it "wrap produces lines that each fit the width" do
        rng = Random.new(321)
        strings = Array.new(200) { Array.new(rng.rand(0..40)) { POOL[rng.rand(POOL.length)] }.join }

        (CORPUS + strings).each do |s|
          DisplayText.new(s).wrap(8).each { |line| expect(line.width).to be <= 8, "#{s.inspect}: #{line.inspect}" }
        end
      end
    end

    describe "render is idempotent" do
      it "re-rendering an identical canvas writes nothing" do
        out = StringIO.new
        screen = Screen.new(nil, StringIO.new, out, :ansi256)
        canvas = Canvas.blank(Size.new(rows: 6, cols: 30))
        CORPUS.first(6).each_with_index { |s, i| canvas.text(i + 1, 1, s) }

        screen.render(canvas)
        out.truncate(out.rewind)
        # identical -> diff is empty
        screen.render(canvas)
        expect(out.string).to eq("")
      end
    end
  end
end
