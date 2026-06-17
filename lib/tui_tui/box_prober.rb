# frozen_string_literal: true

require_relative "box_chrome"

module TuiTui
  # Measures how many columns a string of box-drawing glyphs actually occupies on
  # the live terminal, by printing them and asking for the cursor position (DSR).
  class BoxProber
    # Cursor Position Report: ESC [ row ; col R -> capture the column.
    CPR = /\e\[\d+;(\d+)R/
    MAX_REPLY_BYTES = 64

    def initialize(glyphs: BoxChrome::PROBE_GLYPHS, timeout: 0.2, wait: nil)
      @glyphs = glyphs
      @timeout = timeout
      @wait = wait || method(:wait_readable)
    end

    def measure_all(input:, output:)
      output.write("\r")     # known baseline: column 1
      output.write(@glyphs)  # advances by the sum of glyph widths
      output.write("\e[6n")  # DSR: request cursor position
      output.flush
      col = read_column(input)
      cleanup(output)
      col.nil? ? -1 : col - 1
    end

    private

    # Wipe the probe line before the first render (the alt screen stays clean).
    def cleanup(output)
      output.write("\r\e[K")
      output.flush
    end

    def read_column(input)
      deadline = monotonic + @timeout
      buf = +""
      loop do
        remaining = deadline - monotonic
        break if remaining <= 0
        break unless @wait.call(input, remaining)

        char = input.getc
        break if char.nil?

        buf << char
        if (match = CPR.match(buf))
          return match[1].to_i
        end
        break if buf.bytesize > MAX_REPLY_BYTES
      end
      nil
    end

    def wait_readable(io, timeout) = io.wait_readable(timeout)

    def monotonic = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
