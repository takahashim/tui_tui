# frozen_string_literal: true

require "spec_helper"

module TuiTui
  RSpec.describe RenderContext do
    let(:size) { Size.new(rows: 4, cols: 6) }

    it "delegates rows/cols so it is a drop-in for Size" do
      ctx = RenderContext.new(size: size, chrome: BoxChrome::ASCII)
      expect([ctx.rows, ctx.cols]).to eq([4, 6])
      # works wherever a Size is expected (e.g. Canvas.blank)
      expect(Canvas.blank(ctx).cols).to eq(6)
    end

    it "builds a blank canvas carrying the resolved chrome" do
      ctx = RenderContext.new(size: size, chrome: BoxChrome::UNICODE)
      canvas = ctx.canvas
      canvas.frame(Rect.new(row: 1, col: 1, rows: 4, cols: 6))
      expect(canvas.render_row(1, enabled: false)).to eq("┌────┐")
    end
  end
end
