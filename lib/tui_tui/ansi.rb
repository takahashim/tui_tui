# frozen_string_literal: true

module TuiTui
  # Raw VT/ANSI escape sequences as plain strings.
  module Ansi
    # enter alternate screen buffer
    ALT_ON = "\e[?1049h"
    # leave it, restoring the user's scrollback
    ALT_OFF = "\e[?1049l"
    # hide the cursor
    HIDE = "\e[?25l"
    # show it again
    SHOW = "\e[?25h"
    # clear the whole screen
    CLEAR = "\e[2J"
    # clear the current line
    CLEAR_LINE = "\e[2K"
    # move to row 1, col 1
    HOME = "\e[H"
    # reset all SGR attributes
    RESET = "\e[0m"

    # Mouse reporting:
    # 1002 = button-event tracking
    # 1006 = SGR extended coordinates
    MOUSE_ON = "\e[?1002h\e[?1006h"
    MOUSE_OFF = "\e[?1006l\e[?1002l"

    def self.move(row, col) = "\e[#{row};#{col}H"

    # OSC 52: set the terminal clipboard to `text` (base64-encoded).
    def self.clipboard(text) = "\e]52;c;#{[text].pack("m0")}\a"
  end
end
