# frozen_string_literal: true

module TuiTui
  # One terminal cell; a nil char marks the continuation cell of a wide glyph.
  Cell = Data.define(:char, :style) do
    def self.blank = BLANK
    def continuation? = char.nil?
  end

  Cell::BLANK = Cell.new(char: " ", style: nil)
end
