# frozen_string_literal: true

require "spec_helper"

module TuiTui
  RSpec.describe CommandPalette do
    def palette(items = %w[open save save_as quit], **opts, &label)
      CommandPalette.new(items, **opts, &label)
    end

    def draw(palette, rows: 20, cols: 40)
      size = Size.new(rows: rows, cols: cols)
      palette.draw(Canvas.blank(size), size)
    end

    it "starts on the first item with no query" do
      cp = palette

      expect(cp.query).to eq("")
      expect(cp.selection).to eq("open")
    end

    it "typing narrows the list and resets the cursor to the top match" do
      cp = palette

      expect(cp.handle("s")).to be_nil
      expect(cp.query).to eq("s")
      expect(cp.selection).to eq("save")
    end

    it "backspace widens the query again" do
      cp = palette
      cp.handle("q")
      expect(cp.selection).to eq("quit")

      cp.handle(:backspace)
      expect(cp.query).to eq("")
      expect(cp.selection).to eq("open")
    end

    it "ignores non-printable input in the query" do
      cp = palette

      expect(cp.handle("\t")).to be_nil
      expect(cp.query).to eq("")
    end

    it "enter returns the highlighted item" do
      cp = palette
      cp.handle("s")

      expect(cp.handle("\r")).to eq("save")
    end

    it "enter returns nil while nothing matches (stays open)" do
      cp = palette
      "zzz".each_char { |c| cp.handle(c) }

      expect(cp.selection).to be_nil
      expect(cp.handle("\r")).to be_nil
    end

    it "escape cancels" do
      expect(palette.handle(:escape)).to eq(:cancel)
    end

    it "arrows and Ctrl-N/Ctrl-P move the highlight" do
      cp = palette

      expect(cp.handle(:down)).to be_nil
      expect(cp.selection).to eq("save")
      cp.handle(KeyCode::CTRL_N)
      expect(cp.selection).to eq("save_as")
      cp.handle(KeyCode::CTRL_P)
      expect(cp.selection).to eq("save")
      cp.handle(:up)
      expect(cp.selection).to eq("open")
    end

    it "home and end jump to the ends" do
      cp = palette

      cp.handle(:end)
      expect(cp.selection).to eq("quit")
      cp.handle(:home)
      expect(cp.selection).to eq("open")
    end

    it "the mouse wheel scrolls the highlight" do
      cp = palette(("a".."z").to_a)
      cp.handle(:end) # cursor at last
      top = cp.selection

      expect(cp.handle_mouse(MouseEvent.new(action: :wheel, button: :wheel_up, col: 1, row: 1))).to be_nil
      expect(cp.selection).not_to eq(top)
    end

    it "a click picks the row under the pointer; a miss stays open" do
      cp = palette
      draw(cp)
      rect = cp.instance_variable_get(:@items_rect)

      expect(cp.handle_mouse(MouseEvent.new(action: :press, button: :left, col: rect.col, row: rect.row + 2))).to(
        eq("save_as")
      )
      expect(cp.handle_mouse(MouseEvent.new(action: :press, button: :left, col: 1, row: 1))).to be_nil
    end

    it "derives labels from a block and returns the underlying item" do
      Cmd = Struct.new(:name) unless defined?(Cmd)
      items = [Cmd.new("Reload"), Cmd.new("Restart")]
      cp = CommandPalette.new(items) { |c| c.name }

      cp.handle("e") # subsequence in both; "Reload" ranks first
      expect(cp.handle("\r")).to be(items.first)
    end

    it "draws the prompt, items, and matched query, with an ascii frame" do
      cp = palette
      cp.handle("s")
      cp.handle("a")
      canvas = draw(cp)
      screen = (1..20).map { |r| canvas.render_row(r, enabled: false) }.join("\n")

      expect(screen).to include("> sa")
      expect(screen).to include("save")
      expect(screen).to include("+--")
      expect(screen).not_to include("│")
    end

    it "shows a placeholder when empty and 'No matches' when the query excludes all" do
      cp = palette(placeholder: "Run a command")
      blank = draw(cp)
      expect((1..20).map { |r| blank.render_row(r, enabled: false) }.join("\n")).to include("Run a command")

      "zzz".each_char { |c| cp.handle(c) }
      none = draw(cp)
      expect((1..20).map { |r| none.render_row(r, enabled: false) }.join("\n")).to include("No matches")
    end
  end
end
