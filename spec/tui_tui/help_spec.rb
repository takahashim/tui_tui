# frozen_string_literal: true

require "spec_helper"

module TuiTui
  RSpec.describe Help do
    let (:help) do
      Help.new("Keys", [["j/k", "move"], ["q", "quit"]])
    end

    it "any key closes" do
      expect(help.handle("x")).to eq(:close)
      expect(help.handle(:escape)).to eq(:close)
    end

    it "draw lists keys and descriptions" do
      size = Size.new(rows: 12, cols: 40)
      canvas = Canvas.blank(size)
      help.draw(canvas, size)
      screen = (1..12).map { |r| canvas.render_row(r, enabled: false) }.join("\n")
      expect(screen).to include("Keys")
      expect(screen).to include("j/k")
      expect(screen).to include("move")
      expect(screen).to include("quit")
      expect(screen).to include("+--")
    end
  end
end
