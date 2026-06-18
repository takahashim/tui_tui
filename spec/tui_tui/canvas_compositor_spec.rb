# frozen_string_literal: true

require "spec_helper"
require "benchmark"

module TuiTui
  RSpec.describe CanvasCompositor do
    # :none keeps the painted text plain
    subject(:compositor) { described_class.new(depth: :none) }

    it "full-repaints when there is no previous canvas (CLEAR + every row)" do
      canvas = Canvas.new(2, 3)
      canvas.text(1, 1, "ab")

      out = compositor.render(nil, canvas)
      expect(out).to start_with(Ansi::CLEAR)
      expect(out).to include(Ansi.move(1, 1), "ab")
      # second row repainted too
      expect(out).to include(Ansi.move(2, 1))
    end

    it "writes only the rows that changed" do
      previous = Canvas.new(2, 3)
      previous.text(1, 1, "ab")
      next_canvas = Canvas.new(2, 3)
      next_canvas.text(1, 1, "ab")
      next_canvas.text(2, 1, "xy")

      out = compositor.render(previous, next_canvas)
      expect(out).not_to include(Ansi::CLEAR)
      expect(out).to include(Ansi.move(2, 1), "xy")
      # row 1 unchanged -> skipped
      expect(out).not_to include(Ansi.move(1, 1))
    end

    it "repaints only the changed span of a row, skipping the unchanged start" do
      previous = Canvas.new(1, 10)
      previous.text(1, 1, "hello")
      nxt = Canvas.new(1, 10)
      # only columns 4-5 differ ("lo" -> "p!")
      nxt.text(1, 1, "help!")

      out = compositor.render(previous, nxt)
      # positioned at the first changed column
      expect(out).to include(Ansi.move(1, 4))
      # unchanged "hel" prefix is not repainted
      expect(out).not_to include(Ansi.move(1, 1))
      expect(out).to include("p!")
    end

    it "backs the span start off a wide-char continuation cell" do
      previous = Canvas.new(1, 6)
      # wide: cols 1-2, 3-4
      previous.text(1, 1, "あい")
      nxt = Canvas.new(1, 6)
      # only the second glyph changed (cols 3-4)
      nxt.text(1, 1, "あう")

      out = compositor.render(previous, nxt)
      # starts at the glyph base (col 3), not col 4
      expect(out).to include(Ansi.move(1, 3), "う")
    end

    it "produces nothing when no row changed" do
      same = Canvas.new(1, 3)
      same.text(1, 1, "ab")
      other = Canvas.new(1, 3)
      other.text(1, 1, "ab")

      expect(compositor.render(same, other)).to eq("")
    end

    it "full-repaints when the size changed" do
      previous = Canvas.new(1, 3)
      previous.text(1, 1, "ab")

      out = compositor.render(previous, Canvas.new(2, 3))
      expect(out).to start_with(Ansi::CLEAR)
    end

    # N6 (performance): redraw cost tracks the number of *changed* rows, not the
    # screen size — the property that keeps movement instant on a large board.
    describe "diff cost is proportional to the change, not the screen (N6)" do
      def filled(rows, cols, char)
        canvas = Canvas.new(rows, cols)
        (1..rows).each { |r| canvas.text(r, 1, char * cols) }
        canvas
      end

      it "a single changed row repaints just that one row on a large canvas" do
        previous = filled(200, 200, "a")
        nxt = filled(200, 200, "a")
        # change exactly one of 200 rows
        nxt.text(100, 1, "b" * 200)

        out = compositor.render(previous, nxt)
        expect(out).to include(Ansi.move(100, 1))
        # Exactly one row-positioning move is emitted, regardless of the 200-row
        # canvas: the output is one row's worth, not the whole screen.
        expect(out.scan(/\e\[\d+;1H/).size).to eq(1)
      end

      it "diffing a worst-case full 200x200 frame stays well under the frame budget" do
        skip "timing-sensitive on shared CI runners" if ENV["CI"]

        previous = filled(200, 200, "a")
        # every row differs -> full repaint each time
        nxt = filled(200, 200, "b")

        # Warm up, then take the *fastest* frame: scheduler/GC noise only ever
        # adds time, so the minimum is the most stable estimate of intrinsic
        # cost -- an averaged budget is what made this assertion flaky.
        20.times { compositor.render(previous, nxt) }
        best = Array.new(50) { Benchmark.realtime { compositor.render(previous, nxt) } }.min

        # Generous headroom over the real worst case (~15 ms) while still
        # catching an order-of-magnitude regression.
        expect(best).to be < 0.05
      end
    end
  end
end
