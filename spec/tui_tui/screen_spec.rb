# frozen_string_literal: true

require "spec_helper"
require "stringio"

module TuiTui
  RSpec.describe Screen do
    # The driver only opens when stdout is a real terminal; with a non-tty
    # output it yields nil so the caller can fall back to plain text (F5). This
    # is the one Screen behavior testable without a pty.
    it "run yields nil without a terminal" do
      seen = :unset
      Screen.run(output: StringIO.new) { |screen| seen = screen }
      expect(seen).to be_nil
    end

    it "run does not write to a non terminal" do
      out = StringIO.new
      Screen.run(output: out) { |_screen| nil }
      expect(out.string).to eq("")
    end

    # render diffs against the previous canvas; invalidate drops it so the next
    # render is a full repaint (clears the screen) — the Ctrl-L recovery path.
    it "invalidate forces a full repaint" do
      out = StringIO.new
      screen = Screen.new(nil, StringIO.new, out, :ansi256)
      canvas = Canvas.blank(Size.new(rows: 3, cols: 10))

      screen.render(canvas)
      # first render is full
      expect(out.string).to include(Ansi::CLEAR)

      out.truncate(out.rewind)
      # identical canvas -> nothing redrawn
      screen.render(canvas)
      expect(out.string).not_to include(Ansi::CLEAR)

      out.truncate(out.rewind)
      screen.invalidate
      # forced full repaint
      screen.render(canvas)
      expect(out.string).to include(Ansi::CLEAR)
    end

    # Mouse reporting is on by default, with an env escape hatch for terminals or
    # sessions where it is unwanted.
    describe ".mouse_default" do
      around do |example|
        saved = ENV["TUITUI_MOUSE"]
        example.run
        ENV["TUITUI_MOUSE"] = saved
      end

      it "is on by default" do
        ENV.delete("TUITUI_MOUSE")
        expect(Screen.mouse_default).to be(true)
      end

      it "is turned off by the env var" do
        ENV["TUITUI_MOUSE"] = "0"
        expect(Screen.mouse_default).to be(false)
      end
    end

    it "does not emit mouse sequences when mouse is disabled" do
      out = StringIO.new
      screen = Screen.new(nil, StringIO.new, out, :ansi256, mouse: false)
      # close writes restore sequences; with mouse off none are mouse
      screen.close
      expect(out.string).not_to include(Ansi::MOUSE_OFF)
    end

    # The hardware cursor is hidden unless the canvas requests a position, so the
    # IME candidate window anchors to the character being edited.
    describe "cursor directive" do
      it "hides the cursor when the canvas has none" do
        out = StringIO.new
        screen = Screen.new(nil, StringIO.new, out, :ansi256)
        screen.render(Canvas.blank(Size.new(rows: 3, cols: 10)))
        expect(out.string).to end_with(Ansi::HIDE)
        expect(out.string).not_to include(Ansi::SHOW)
      end

      it "moves and shows the cursor at the canvas position" do
        out = StringIO.new
        screen = Screen.new(nil, StringIO.new, out, :ansi256)
        canvas = Canvas.blank(Size.new(rows: 3, cols: 10)).cursor_at(2, 4)
        screen.render(canvas)
        expect(out.string).to end_with(Ansi.move(2, 4) + Ansi::SHOW)
      end
    end

    it "copy writes the OSC 52 clipboard sequence" do
      out = StringIO.new
      screen = Screen.new(nil, StringIO.new, out, :ansi256)
      screen.copy("hi")
      expect(out.string).to eq(Ansi.clipboard("hi"))
      # base64("hi") = aGk=
      expect(out.string).to eq("\e]52;c;aGk=\a")
    end
  end
end
