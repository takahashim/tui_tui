# frozen_string_literal: true

require_relative "event"
require_relative "key_code"

module TuiTui
  # Decodes raw-mode terminal input into literal keys, named keys, and mouse events.
  class KeyReader
    ESCAPES = {
      "\e[A" => :up,
      "\e[B" => :down,
      "\e[C" => :right,
      "\e[D" => :left,
      "\eOA" => :up,
      "\eOB" => :down,
      "\eOC" => :right,
      "\eOD" => :left,
      "\e[H" => :home,
      "\e[F" => :end,
      "\eOH" => :home,
      "\eOF" => :end,
      "\e[1~" => :home,
      "\e[4~" => :end,
      "\e[5~" => :pgup,
      "\e[6~" => :pgdn,
      "\e[3~" => :delete,
      "\e[Z" => :backtab
    }.freeze

    ESCAPE_TAIL_BYTES = 256

    # SGR mouse reports can grow with coordinate length; decode the first report
    # if several drag reports arrive in one non-blocking read.
    MOUSE = /\A\[<(\d+);(\d+);(\d+)([Mm])/.freeze
    MOUSE_MOTION = 0x20
    MOUSE_WHEEL = 0x40

    # A modified special key arrives as a CSI with a "1;<mod>" parameter, e.g.
    # Ctrl+Right = "\e[1;5C", Shift+Up = "\e[1;2A", Ctrl+Delete = "\e[3;5~".
    # MOD encodes the held modifiers as (1 + Shift(1) + Alt(2) + Ctrl(4)).
    MODIFIED = /\A\[(\d*);(\d+)([A-Za-z~])/.freeze
    MOD_LETTER = {"A" => :up, "B" => :down, "C" => :right, "D" => :left, "H" => :home, "F" => :end}.freeze
    MOD_TILDE = {1 => :home, 3 => :delete, 4 => :end, 5 => :pgup, 6 => :pgdn, 7 => :home, 8 => :end}.freeze
    MOD_BITS = {shift: 1, alt: 2, ctrl: 4}.freeze

    # One keypress/event from `io` (String, Symbol, or MouseEvent), nil at EOF.
    def read(io) = read_all(io)&.first

    def read_all(io)
      first = io.getch
      return nil if first.nil?
      return decode_escape_events(read_escape_tail(io)) if first == KeyCode::ESCAPE
      return [assemble_utf8(io, first)] if first.bytesize == 1 && first.getbyte(0) >= 0x80

      [first]
    end

    def decode_escape(rest)
      return :escape if rest.nil? || rest.empty?

      mouse = decode_mouse(rest)
      return mouse if mouse

      modified = decode_modified(rest)
      return modified if modified

      ESCAPES["\e" + rest] || :escape
    end

    # Decode a whole ESC tail into events, batching consecutive mouse reports
    # (and otherwise yielding a single key/escape).
    def decode_escape_events(rest)
      return [:escape] if rest.nil? || rest.empty?

      mice = []
      remainder = rest
      loop do
        remainder = remainder.sub(/\A\e/, "")
        match = MOUSE.match(remainder) or break

        mice << mouse_event_from(match)
        remainder = match.post_match
      end

      mice.empty? ? [decode_escape(rest)] : mice
    end

    private

    def decode_modified(rest)
      match = MODIFIED.match(rest)
      return nil unless match

      final = match[3]
      base = final == "~" ? MOD_TILDE[match[1].to_i] : MOD_LETTER[final]
      return nil unless base

      prefix = modifier_prefix(match[2].to_i)
      return nil unless prefix

      prefix.empty? ? base : :"#{prefix}_#{base}"
    end

    # "ctrl", "shift", "ctrl_shift", ... for an xterm modifier parameter, "" for
    # no modifiers, or nil when the value is out of range.
    def modifier_prefix(mod)
      bits = mod - 1
      return nil if bits.negative? || bits > 7

      %i[ctrl alt shift].select { |name| bits.anybits?(MOD_BITS[name]) }.join("_")
    end

    def read_escape_tail(io)
      rest = io.read_nonblock(ESCAPE_TAIL_BYTES, exception: false)
      rest.is_a?(String) ? rest : nil
    end

    def assemble_utf8(io, lead)
      # Raw mode may deliver multibyte input one byte at a time.
      bytes = +lead.b
      utf8_continuation_count(lead.getbyte(0)).times do
        nxt = io.read_nonblock(1, exception: false)
        break unless nxt.is_a?(String) && !nxt.empty?

        bytes << nxt
      end

      char = bytes.force_encoding("UTF-8")
      char.valid_encoding? ? char : :unknown
    end

    def utf8_continuation_count(byte)
      return 1 if byte.between?(0xC0, 0xDF)
      return 2 if byte.between?(0xE0, 0xEF)
      return 3 if byte.between?(0xF0, 0xF7)

      0
    end

    def decode_mouse(rest)
      match = MOUSE.match(rest)
      match && mouse_event_from(match)
    end

    def mouse_event_from(match)
      mouse_event(match[1].to_i, match[2].to_i, match[3].to_i, match[4] == "m")
    end

    def mouse_event(flags, col, row, released)
      if flags & MOUSE_WHEEL != 0
        button = (flags & 0b1).zero? ? :wheel_up : :wheel_down
        MouseEvent.new(action: :wheel, button: button, col: col, row: row)
      elsif flags & MOUSE_MOTION != 0
        MouseEvent.new(action: :drag, button: button_name(flags), col: col, row: row)
      elsif released
        MouseEvent.new(action: :release, button: button_name(flags), col: col, row: row)
      else
        MouseEvent.new(action: :press, button: button_name(flags), col: col, row: row)
      end
    end

    def button_name(flags)
      case flags & 0b11
      when 0
        :left
      when 1
        :middle
      when 2
        :right
      else
        :none
      end
    end
  end
end
