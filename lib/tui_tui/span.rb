# frozen_string_literal: true

require_relative "display_text"

module TuiTui
  # A run of text sharing one Style.
  # Width is terminal-column aware via DisplayText.
  Span = Data.define(:text, :style) do
    # Data.define auto-generates Span.[] as an alias of .new. Remove it before
    # redefining so our convenience form (style optional, text coerced) does not
    # print a "method redefined" warning under -w.
    singleton_class.send(:remove_method, :[])

    # Convenience constructor: Span["hi", style] (style optional).
    def self.[](text, style = nil) = new(text: text.to_s, style: style)

    def width = DisplayText.new(text).width
  end
end
