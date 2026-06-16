# frozen_string_literal: true

require_relative "size"

module TuiTui
  # Reads winsize with a fallback that keeps layout deterministic in tests and PTYs.
  class TerminalSize
    DEFAULT = Size.new(rows: 24, cols: 80)

    def initialize(console, default: DEFAULT)
      @console = console
      @default = default
    end

    def size
      rows, cols = @console.winsize
      return @default if rows.to_i.zero? || cols.to_i.zero?

      Size.new(rows: rows, cols: cols)
    rescue StandardError
      @default
    end
  end
end
