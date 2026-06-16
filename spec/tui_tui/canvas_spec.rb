# frozen_string_literal: true

require "spec_helper"

module TuiTui
  # Cell-grid drawing: ASCII, wide chars (with continuation cells), clipping at
  # the edge, fills, combining marks, row rendering, and row equality.
  RSpec.describe Canvas do
    it "blank row is spaces" do
      canvas = Canvas.new(3, 10)

      expect(canvas.render_row(1, enabled: false)).to eq("          ")
    end

    it "text writes ascii" do
      canvas = Canvas.new(3, 10)

      canvas.text(1, 1, "hello")
      expect(canvas.render_row(1, enabled: false)).to eq("hello     ")
    end

    describe "#cursor_at" do
      it "records an in-bounds position and chains" do
        canvas = Canvas.new(3, 10)

        expect(canvas.cursor).to be_nil
        expect(canvas.cursor_at(2, 5)).to be(canvas)
        expect(canvas.cursor).to eq([2, 5])
      end

      it "ignores an out-of-bounds position (cursor stays hidden)" do
        canvas = Canvas.new(3, 10)

        canvas.cursor_at(99, 99)
        expect(canvas.cursor).to be_nil
      end
    end

    it "text at offset column" do
      canvas = Canvas.new(3, 10)

      canvas.text(1, 4, "hi")
      expect(canvas.render_row(1, enabled: false)).to eq("   hi     ")
    end

    it "wide char occupies two columns" do
      canvas = Canvas.new(3, 10)

      canvas.text(1, 1, "あ!")
      # "あ" fills two columns (rendered once), then "!" — total visible width 3.
      expect(canvas.render_row(1, enabled: false)).to eq("あ!       ")
      expect(canvas.cell(1, 1).char).to eq("あ")
      # continuation
      expect(canvas.cell(1, 2).char).to be_nil
      expect(canvas.cell(1, 3).char).to eq("!")
    end

    it "wide char clipped at edge is dropped" do
      canvas = Canvas.new(1, 3)
      # 'a' at col1, 'あ' would straddle cols 2-3? fits (2,3)
      canvas.text(1, 1, "aあ")
      expect(canvas.render_row(1, enabled: false)).to eq("aあ")

      narrow = Canvas.new(1, 2)
      # would need cols 2-3, only col 2 exists -> dropped
      narrow.text(1, 2, "あ")
      # both cells stay blank
      expect(narrow.render_row(1, enabled: false)).to eq("  ")
    end

    it "clips ascii past right edge" do
      canvas = Canvas.new(1, 4)

      canvas.text(1, 1, "abcdef")
      expect(canvas.render_row(1, enabled: false)).to eq("abcd")
    end

    it "combining mark folds into base" do
      canvas = Canvas.new(3, 10)

      # e + combining acute + x
      canvas.text(1, 1, "éx")
      expect(canvas.render_row(1, enabled: false).rstrip).to eq("éx")
    end

    it "overwriting the left half of a wide glyph clears the orphaned right half" do
      canvas = Canvas.new(1, 4)
      # あ at 1-2, x at 3
      canvas.text(1, 1, "あx")
      # narrow over the wide base
      canvas.text(1, 1, "b")

      # col 2's stale continuation is gone, so the row keeps its width.
      expect(canvas.render_row(1, enabled: false)).to eq("b x ")
      expect(canvas.cell(1, 2).continuation?).to be(false)
    end

    it "overwriting the right half of a wide glyph clears the orphaned left half" do
      canvas = Canvas.new(1, 4)
      # あ at 1-2
      canvas.text(1, 1, "あx")
      # narrow into the continuation cell
      canvas.text(1, 2, "y")

      # the あ base became blank
      expect(canvas.render_row(1, enabled: false)).to eq(" yx ")
    end

    it "fill never emits a raw control byte (same sink guarantee as text)" do
      canvas = Canvas.new(1, 3)

      # an ESC fill char
      canvas.fill(Rect.new(row: 1, col: 1, rows: 1, cols: 3), nil, "\e")
      # scrubbed to CONTROL_GLYPH
      expect(canvas.render_row(1, enabled: false)).to eq("???")
    end

    it "fill paints region" do
      canvas = Canvas.new(2, 5)

      canvas.fill(Rect.new(row: 1, col: 2, rows: 1, cols: 3), nil, "#")
      expect(canvas.render_row(1, enabled: false)).to eq(" ### ")
    end

    it "line paints styled spans in sequence, advancing by display width" do
      canvas = Canvas.new(1, 12)

      canvas.line(1, 1, [Span["あ", Style.new(fg: :red)], Span["x", Style.new(fg: :blue)]])
      # "あ" claims cols 1-2 (its style), "x" lands at col 3 (its style).
      expect(canvas.cell(1, 1).char).to eq("あ")
      expect(canvas.cell(1, 1).style).to eq(Style.new(fg: :red))
      # wide continuation
      expect(canvas.cell(1, 2).char).to be_nil
      expect(canvas.cell(1, 3).char).to eq("x")
      expect(canvas.cell(1, 3).style).to eq(Style.new(fg: :blue))
    end

    it "render row applies style when enabled" do
      canvas = Canvas.new(3, 10)

      canvas.text(1, 1, "hi", Style.new(fg: :red))
      # "hi" painted as one run, then the 8 blank cells as a plain run.
      expect(canvas.render_row(1, depth: :ansi256, enabled: true)).to eq("\e[31mhi\e[0m#{" " * 8}")
    end

    it "same row detects changes" do
      a = Canvas.new(3, 10)
      b = Canvas.new(3, 10)

      expect(a.same_row?(b, 1)).to be_truthy
      b.text(1, 1, "x")
      expect(a.same_row?(b, 1)).to be_falsey
    end

    it "frame draws an ASCII border and clears the interior" do
      canvas = Canvas.new(4, 6)

      # content the frame must erase
      canvas.text(2, 2, "OLD")
      canvas.frame(Rect.new(row: 1, col: 1, rows: 4, cols: 6))

      rows = (1..4).map { |r| canvas.render_row(r, enabled: false) }
      expect(rows).to eq(["+----+", "|    |", "|    |", "+----+"])
    end

    it "frames only the given sub-rectangle" do
      canvas = Canvas.new(3, 10)

      canvas.frame(Rect.new(row: 1, col: 2, rows: 3, cols: 4))
      expect(canvas.render_row(1, enabled: false)).to eq(" +--+     ")
    end
  end
end
