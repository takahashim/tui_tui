# frozen_string_literal: true

require "spec_helper"

module TuiTui
  RSpec.describe TerminalSize do
    # A fake console whose winsize returns a canned value or raises.
    Console = Struct.new(:winsize) do
      def winsize = self[:winsize].is_a?(Exception) ? raise(self[:winsize]) : self[:winsize]
    end

    it "reports the console winsize" do
      default = Size.new(rows: 24, cols: 80)

      ts = TerminalSize.new(Console.new([40, 120]), default: default)
      expect(ts.size).to eq(Size.new(rows: 40, cols: 120))
    end

    it "falls back to the default when winsize is zero" do
      default = Size.new(rows: 24, cols: 80)

      expect(TerminalSize.new(Console.new([0, 0]), default: default).size).to eq(default)
    end

    it "falls back to the default when winsize raises" do
      default = Size.new(rows: 24, cols: 80)

      ts = TerminalSize.new(Console.new(Errno::ENOTTY.new), default: default)
      expect(ts.size).to eq(default)
    end
  end
end
