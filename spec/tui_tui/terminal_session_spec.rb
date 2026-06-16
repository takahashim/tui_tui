# frozen_string_literal: true

require "spec_helper"
require "stringio"

module TuiTui
  RSpec.describe TerminalSession do
    TerminalSessionConsole = Struct.new(:raws, :cookeds) do
      def raw! = self.raws += 1
      def cooked! = self.cookeds += 1
    end

    TerminalSessionEvents = Struct.new(:resizes) do
      def resized! = self.resizes += 1
    end

    it "enters raw alternate-screen mode and restores it on close" do
      console = TerminalSessionConsole.new(0, 0)
      output = StringIO.new
      session = TerminalSession.new(console: console, output: output, events: TerminalSessionEvents.new(0), mouse: true)

      session.start
      expect(console.raws).to eq(1)
      expect(output.string).to include(Ansi::ALT_ON)
      expect(output.string).to include(Ansi::MOUSE_ON)

      output.truncate(output.rewind)
      session.close

      expect(console.cookeds).to eq(1)
      expect(output.string).to include(Ansi::MOUSE_OFF)
      expect(output.string).to include(Ansi::ALT_OFF)
    ensure
      session&.close
    end

    it "is idempotent when closed repeatedly" do
      console = TerminalSessionConsole.new(0, 0)
      output = StringIO.new
      session = TerminalSession.new(
        console: console,
        output: output,
        events: TerminalSessionEvents.new(0),
        mouse: false
      )

      session.close
      session.close

      expect(console.cookeds).to eq(1)
      expect(output.string.scan(Ansi::ALT_OFF).size).to eq(1)
      expect(output.string).not_to include(Ansi::MOUSE_OFF)
    end
  end
end
