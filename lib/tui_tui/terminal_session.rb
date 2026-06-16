# frozen_string_literal: true

require_relative "ansi"

module TuiTui
  # Owns raw mode, alternate screen, and restoration traps for one TUI session.
  class TerminalSession
    RESTORE_SIGNALS = %w[TERM HUP INT].freeze

    def initialize(console:, output:, events:, mouse:)
      @console = console
      @output = output
      @events = events
      @mouse = mouse
      @closed = false
    end

    def start
      @console.raw!
      @output.write(Ansi::ALT_ON + Ansi::HIDE + Ansi::CLEAR + (@mouse ? Ansi::MOUSE_ON : ""))
      @output.flush
      @prev_winch = trap("WINCH") { @events.resized! }
      install_restore_traps
      at_exit { close }
    end

    def close
      # Close is called from ensure, at_exit, and signal traps.
      return if @closed

      @closed = true
      @output.write((@mouse ? Ansi::MOUSE_OFF : "") + Ansi::SHOW + Ansi::ALT_OFF)
      @output.flush
      begin
        @console.cooked!
      rescue StandardError
        nil
      end

      trap("WINCH", @prev_winch || "DEFAULT") if defined?(@prev_winch)
      restore_signal_traps
    end

    private

    def install_restore_traps
      @prev_signals = {}
      RESTORE_SIGNALS.each do |signal|
        @prev_signals[signal] = trap(signal) do
          # Restore the terminal, then preserve the signal's normal process effect.
          close
          trap(signal, "DEFAULT")
          Process.kill(signal, Process.pid)
        end
      rescue ArgumentError
      end
    end

    def restore_signal_traps
      @prev_signals&.each { |signal, handler| trap(signal, handler || "DEFAULT") }
    rescue ArgumentError
      nil
    end
  end
end
