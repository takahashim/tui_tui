# frozen_string_literal: true

require "spec_helper"

module TuiTui
  RSpec.describe StatusBar do
    def rect(cols) = Rect.new(row: 1, col: 1, rows: 1, cols: cols)

    it "draws the left segment from the start and fills the row" do
      canvas = Canvas.new(1, 10)
      StatusBar.draw(canvas, rect(10), left: "hi")
      expect(canvas.render_row(1, enabled: false)).to eq("hi        ")
    end

    it "right-aligns the right segment, leaving room for the left" do
      canvas = Canvas.new(1, 12)
      StatusBar.draw(canvas, rect(12), left: "dir", right: "1/9")
      expect(canvas.render_row(1, enabled: false)).to eq("dir      1/9")
    end

    it "truncates the left segment to the space the right leaves" do
      canvas = Canvas.new(1, 12)
      StatusBar.draw(canvas, rect(12), left: "a-very-long-left", right: "9/9")
      row = canvas.render_row(1, enabled: false)
      # right kept, flush to the edge
      expect(row).to end_with("9/9")
      # no overflow
      expect(row.length).to eq(12)
      # left did not bleed under the right
      expect(row[0, 9]).not_to include("9")
    end

    it "drops the right segment when it cannot fit" do
      canvas = Canvas.new(1, 4)
      StatusBar.draw(canvas, rect(4), left: "lt", right: "wont-fit")
      # only the left
      expect(canvas.render_row(1, enabled: false)).to eq("lt  ")
    end

    it "applies the bar style across the whole row" do
      canvas = Canvas.new(1, 6)
      bar = Style.new(attrs: [:reverse])
      StatusBar.draw(canvas, rect(6), left: "x", right: "y", style: bar)
      (1..6).each { |c| expect(canvas.cell(1, c).style).to eq(bar) }
    end
  end
end
