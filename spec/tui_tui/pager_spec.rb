# frozen_string_literal: true

require "spec_helper"

module TuiTui
  RSpec.describe Pager do
    it "scroll keys return nil to stay open" do
      pager = Pager.new("Body", (1..50).map { |i| "line #{i}" })

      expect(pager.handle("j")).to be_nil
      expect(pager.handle(:down)).to be_nil
      expect(pager.handle(" ")).to be_nil
    end

    it "q and escape close" do
      pager = Pager.new("Body", (1..50).map { |i| "line #{i}" })

      expect(pager.handle("q")).to eq(:close)
      expect(pager.handle(:escape)).to eq(:close)
    end

    it "mouse wheel scrolls and stays open" do
      pager = Pager.new("Body", (1..50).map { |i| "line #{i}" })
      pager.draw(Canvas.blank(Size.new(rows: 20, cols: 40)), Size.new(rows: 20, cols: 40))

      expect(pager.handle_mouse(MouseEvent.new(action: :wheel, button: :wheel_down, col: 1, row: 1))).to be_nil
      expect(pager.instance_variable_get(:@top)).to eq(Pager::WHEEL)
    end

    it "extra close keys" do
      p = Pager.new("Body", %w[a b], close_keys: ["S"])
      # the key that opened it also closes it
      expect(p.handle("S")).to eq(:close)
      # not a close key by default
      expect(Pager.new("Body", %w[a b]).handle("S")).to be_nil
    end

    it "draw shows title and first lines" do
      pager = Pager.new("Body", (1..50).map { |i| "line #{i}" })
      size = Size.new(rows: 12, cols: 40)
      canvas = Canvas.blank(size)

      pager.draw(canvas, size)
      screen = (1..12).map { |r| canvas.render_row(r, enabled: false) }.join("\n")
      expect(screen).to include("Body")
      expect(screen).to include("line 1")
      expect(screen).to include("+--")
    end

    it "scrolling moves the window" do
      pager = Pager.new("Body", (1..50).map { |i| "line #{i}" })
      size = Size.new(rows: 12, cols: 40)
      canvas = Canvas.blank(size)

      20.times { pager.handle("j") }
      pager.draw(canvas, size)
      screen = (1..12).map { |r| canvas.render_row(r, enabled: false) }.join("\n")
      expect(screen).to include("line 21")
      # scrolled past the top
      expect(screen).not_to include("line 1\n")
    end

    it "scroll clamps at the end" do
      pager = Pager.new("Body", (1..3).map { |i| "line #{i}" })
      size = Size.new(rows: 12, cols: 40)
      canvas = Canvas.blank(size)

      100.times { pager.handle("j") }
      pager.draw(canvas, size)
      screen = (1..12).map { |r| canvas.render_row(r, enabled: false) }.join("\n")
      # never scrolls content off when it all fits
      expect(screen).to include("line 1")
    end
  end
end
