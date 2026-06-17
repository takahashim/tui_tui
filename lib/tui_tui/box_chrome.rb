# frozen_string_literal: true

module TuiTui
  # The glyph set used to draw chrome (frame borders, dividers, scrollbar track).
  BoxChrome = Data.define(:tl, :tr, :bl, :br, :h, :v, :lt, :rt, :tt, :bt, :cross, :track)

  class BoxChrome
    ASCII = new(
      tl: "+", tr: "+", bl: "+", br: "+",
      h: "-", v: "|",
      lt: "+", rt: "+", tt: "+", bt: "+", cross: "+",
      track: "|"
    )

    # Single-line box drawing (U+2500..U+253C).
    UNICODE = new(
      tl: "┌", tr: "┐", bl: "└", br: "┘",
      h: "─", v: "│",
      lt: "├", rt: "┤", tt: "┬", bt: "┴", cross: "┼",
      track: "│"
    )

    # The distinct Unicode glyphs chrome can emit, probed as one string.
    PROBE_GLYPHS = "─│┌┐└┘├┤┬┴┼"

    # Narrower than this and the probe glyphs would wrap at column 1.
    MIN_PROBE_COLS = 12

    # Resolve an override string to a chrome, or :auto when a probe is needed.
    def self.from(name)
      case name.to_s.downcase
      when "ascii", "0", "off", "false" then ASCII
      when "unicode", "1", "on", "true" then UNICODE
      else :auto
      end
    end

    # The capability gate: every probed glyph must render at width 1, so the total
    # advance equals the glyph count.
    def self.supported?(total_width)
      total_width == PROBE_GLYPHS.length
    end

    # Full resolution given a live console. Honors TUITUI_BOX, else probes; falls
    # back to ASCII when forced off, the terminal is too narrow, or the probe fails.
    def self.resolve(input:, output:, term_cols:, env: ENV, prober: BoxProber.new)
      forced = from(env["TUITUI_BOX"].to_s)
      return forced unless forced == :auto
      return ASCII if term_cols < MIN_PROBE_COLS

      supported?(prober.measure_all(input: input, output: output)) ? UNICODE : ASCII
    end
  end
end
