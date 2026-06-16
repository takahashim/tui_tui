# frozen_string_literal: true

require_relative "palette"

module TuiTui
  # Value object for SGR styling. It downgrades richer colors to the selected
  # terminal depth instead of emitting unsupported escape sequences.
  class Style
    NAMED = {
      black: 30,
      red: 31,
      green: 32,
      yellow: 33,
      blue: 34,
      magenta: 35,
      cyan: 36,
      white: 37,
      bright_black: 90,
      bright_red: 91,
      bright_green: 92,
      bright_yellow: 93,
      bright_blue: 94,
      bright_magenta: 95,
      bright_cyan: 96,
      bright_white: 97
    }.freeze

    ATTRS = {bold: 1, dim: 2, italic: 3, underline: 4, reverse: 7}.freeze

    attr_reader :fg, :bg, :attrs

    def initialize(fg: nil, bg: nil, attrs: [])
      @fg = fg
      @bg = bg
      @attrs = attrs
      @palette = Palette.new
    end

    def with(fg: @fg, bg: @bg, attrs: @attrs)
      self.class.new(fg: fg, bg: bg, attrs: attrs)
    end

    def ==(other)
      # Canvas diffing relies on equivalent styles comparing equal.
      other.is_a?(Style) && fg == other.fg && bg == other.bg && attrs == other.attrs
    end

    alias_method :eql?, :==

    def hash = [fg, bg, attrs].hash

    def paint(text, depth: :ansi256, enabled: true)
      return text if !enabled || depth == :none

      codes = sgr_codes(depth)
      return text if codes.empty?

      "\e[#{codes.join(";")}m#{text}\e[0m"
    end

    def sgr_codes(depth)
      codes = @attrs.map { |attr| ATTRS.fetch(attr) }
      codes.concat(color_codes(@fg, depth, ground: :fg))
      codes.concat(color_codes(@bg, depth, ground: :bg))
      codes
    end

    private

    def color_codes(color, depth, ground:)
      case color
      when nil
        []
      when Symbol
        [ground_offset(NAMED.fetch(color), ground)]
      when Integer
        integer_codes(color, depth, ground)
      when Array
        array_codes(color, depth, ground)
      else
        []
      end
    end

    def integer_codes(index, depth, ground)
      return [ground_offset(@palette.nearest_code(@palette.rgb_from_256(index)), ground)] if depth == :basic16

      [ground == :bg ? 48 : 38, 5, index]
    end

    def array_codes(rgb, depth, ground)
      return [ground_offset(@palette.nearest_code(rgb), ground)] if depth == :basic16
      # RGB has no honest representation below truecolor except the basic16 path.
      return [] unless depth == :truecolor

      [ground == :bg ? 48 : 38, 2, *rgb]
    end

    def ground_offset(base, ground) = ground == :bg ? base + 10 : base
  end
end
