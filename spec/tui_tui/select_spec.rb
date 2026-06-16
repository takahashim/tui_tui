# frozen_string_literal: true

require "spec_helper"

module TuiTui
  RSpec.describe Select do
    it "starts at default" do
      select = Select.new("Pick one", %w[Alpha Bravo Charlie], default: 1)

      expect(select.cursor).to eq(1)
    end

    it "movement returns nil and moves" do
      select = Select.new("Pick one", %w[Alpha Bravo Charlie], default: 1)

      expect(select.handle(:down)).to be_nil
      expect(select.cursor).to eq(2)
      expect(select.handle("k")).to be_nil
      expect(select.cursor).to eq(1)
    end

    it "mouse wheel moves the cursor" do
      select = Select.new("Pick one", ("a".."z").to_a, default: 5)

      expect(select.handle_mouse(MouseEvent.new(action: :wheel, button: :wheel_down, col: 1, row: 1))).to be_nil
      expect(select.cursor).to eq(5 + Select::WHEEL)
      select.handle_mouse(MouseEvent.new(action: :wheel, button: :wheel_up, col: 1, row: 1))
      expect(select.cursor).to eq(5)
    end

    it "a click picks the item under the pointer; a miss stays open" do
      select = Select.new("Pick one", %w[a b c d e], default: 0)
      select.draw(Canvas.blank(Size.new(rows: 20, cols: 30)), Size.new(rows: 20, cols: 30))
      rect = select.instance_variable_get(:@items_rect)

      expect(select.handle_mouse(MouseEvent.new(action: :press, button: :left, col: rect.col, row: rect.row + 2))).to(
        eq(2)
      )
      # outside the list
      expect(select.handle_mouse(MouseEvent.new(action: :press, button: :left, col: 1, row: 1))).to be_nil
    end

    it "enter returns the index" do
      select = Select.new("Pick one", %w[Alpha Bravo Charlie], default: 1)

      expect(select.handle("\r")).to eq(1)
    end

    it "escape cancels" do
      select = Select.new("Pick one", %w[Alpha Bravo Charlie], default: 1)

      expect(select.handle(:escape)).to eq(:cancel)
    end

    it "home end" do
      select = Select.new("Pick one", %w[Alpha Bravo Charlie], default: 1)

      select.handle(:end)
      expect(select.cursor).to eq(2)
      select.handle("g")
      expect(select.cursor).to eq(0)
    end

    it "draw renders title items and ascii frame" do
      select = Select.new("Pick one", %w[Alpha Bravo Charlie], default: 1)
      size = Size.new(rows: 20, cols: 40)
      canvas = Canvas.blank(size)

      select.draw(canvas, size)
      screen = (1..20).map { |r| canvas.render_row(r, enabled: false) }.join("\n")
      expect(screen).to include("Pick one")
      expect(screen).to include("Alpha")
      expect(screen).to include("Charlie")
      expect(screen).to include("+--")
      expect(screen).not_to include("│")
    end
  end
end
