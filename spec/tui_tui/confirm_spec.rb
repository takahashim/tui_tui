# frozen_string_literal: true

require "spec_helper"

module TuiTui
  # The modal's key folding (pure) and its ASCII-only rendering.
  RSpec.describe Confirm do
    it "defaults to cancel focus" do
      expect(Confirm.new("Quit?").focus).to eq(:cancel)
    end

    it "movement toggles focus and returns nil" do
      dialog = Confirm.new("Quit?")
      expect(dialog.handle("\t")).to be_nil
      expect(dialog.focus).to eq(:ok)
      expect(dialog.handle(:left)).to be_nil
      expect(dialog.focus).to eq(:cancel)
    end

    it "a click resolves the button under the pointer" do
      dialog = Confirm.new("Proceed?")
      dialog.draw(Canvas.blank(Size.new(rows: 12, cols: 40)), Size.new(rows: 12, cols: 40))
      row = dialog.instance_variable_get(:@buttons_row)

      expect(
        dialog.handle_mouse(
          MouseEvent.new(action: :press, button: :left, col: dialog.instance_variable_get(:@ok_at), row: row)
        )
      )
        .to eq(:ok)
      expect(
        dialog.handle_mouse(
          MouseEvent.new(action: :press, button: :left, col: dialog.instance_variable_get(:@cancel_at), row: row)
        )
      )
        .to eq(:cancel)
      expect(dialog.handle_mouse(MouseEvent.new(action: :press, button: :left, col: 1, row: row + 5))).to be_nil
    end

    it "enter confirms the focused button" do
      dialog = Confirm.new("Quit?", default: :ok)
      expect(dialog.handle("\r")).to eq(:ok)
    end

    it "enter on default cancel" do
      expect(Confirm.new("Quit?").handle("\r")).to eq(:cancel)
    end

    it "letter shortcuts" do
      expect(Confirm.new("Quit?").handle("y")).to eq(:ok)
      expect(Confirm.new("Quit?").handle("n")).to eq(:cancel)
    end

    it "escape cancels" do
      expect(Confirm.new("Quit?").handle(:escape)).to eq(:cancel)
    end

    it "unrelated key keeps it open" do
      expect(Confirm.new("Quit?").handle("x")).to be_nil
    end

    it "draw renders message and ascii buttons" do
      canvas = Canvas.blank(Size.new(rows: 12, cols: 40))
      Confirm.new("Quit file browser?").draw(canvas, Size.new(rows: 12, cols: 40))
      screen = (1..12).map { |r| canvas.render_row(r, enabled: false) }.join("\n")
      expect(screen).to include("Quit file browser?")
      expect(screen).to include("[ OK ]")
      expect(screen).to include("[ Cancel ]")
      # ASCII border (N7), not box-drawing
      expect(screen).to include("+----")
      # no Unicode box-drawing
      expect(screen).not_to include("─")
    end
  end
end
