# frozen_string_literal: true

require_relative "width"
require_relative "text_sanitizer"

module TuiTui
  # String wrapper for width-aware truncation, centering, and wrapping.
  class DisplayText
    def initialize(string)
      @string = string.is_a?(DisplayText) ? string.to_s : TextSanitizer.sanitize(string.to_s)
    end

    def to_s = @string

    def width
      @string.each_grapheme_cluster.sum { |grapheme| Width.cluster(grapheme) }
    end

    def truncate(max, marker: "...")
      return self.class.new("") if max <= 0
      return self if width <= max

      marker = self.class.new(marker)
      budget = [max - marker.width, 0].max
      kept = +""
      used = 0
      @string.each_grapheme_cluster do |grapheme|
        grapheme_width = Width.cluster(grapheme)
        break if used + grapheme_width > budget

        kept << grapheme
        used += grapheme_width
      end

      self.class.new(kept + marker.to_s)
    end

    def center(columns)
      gap = columns - width
      return self if gap <= 0

      left = gap / 2
      self.class.new((" " * left) + @string + (" " * (gap - left)))
    end

    def wrap(max, indent: "")
      return [self] if max <= 0 || width <= max

      indent = self.class.new(indent)
      chunks = []
      current = +""
      current_width = 0
      budget = max
      @string.each_grapheme_cluster do |grapheme|
        grapheme_width = Width.cluster(grapheme)
        if current_width + grapheme_width > budget && !current.empty?
          chunks << current
          current = +""
          current_width = 0
          budget = [max - indent.width, 1].max
        end

        current << grapheme
        current_width += grapheme_width
      end

      chunks << current unless current.empty?
      return [self] if chunks.empty?

      [self.class.new(chunks.first)] + chunks[1..].map { |chunk| self.class.new(indent.to_s + chunk) }
    end
  end
end
