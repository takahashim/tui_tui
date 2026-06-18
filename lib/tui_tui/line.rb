# frozen_string_literal: true

require_relative "span"
require_relative "display_text"

module TuiTui
  # An ordered list of styled Spans.
  # Width-aware truncation preserves each span's style.
  class Line
    # Convenience constructor: Line[Span["a", s1], Span["b", s2]].
    def self.[](*spans) = new(spans)

    # Coerce loose content into a Line: a Line passes through, an Array becomes
    # its spans, and anything else is one Span (in `style`, when given).
    def self.coerce(content, style = nil)
      case content
      when Line then content
      when Array then new(content)
      else Line[Span[content.to_s, style]]
      end
    end

    def initialize(spans = [])
      @spans = spans
    end

    attr_reader :spans

    def width = @spans.sum(&:width)
    def each(&block) = @spans.each(&block)
    def to_s = @spans.map(&:text).join

    # Truncate to `max` columns, keeping span styles. When content is dropped,
    # `marker` is appended in the style of the span it cut into; the marker's own
    # width is reserved so the result never exceeds `max`.
    def truncate(max, marker: "...")
      return self if width <= max

      budget = max - DisplayText.new(marker).width
      if budget <= 0
        clipped = DisplayText.new(marker).truncate(max, marker: "").to_s
        return self.class.new([Span[clipped, @spans.first&.style]])
      end

      take_until(budget, marker)
    end

    private

    def take_until(budget, marker)
      kept = []
      used = 0
      @spans.each do |span|
        if used + span.width <= budget
          kept << span
          used += span.width
          next
        end

        room = budget - used
        kept << Span[DisplayText.new(span.text).truncate(room, marker: "").to_s, span.style] if room.positive?
        kept << Span[marker, (kept.last || span).style]
        break
      end

      self.class.new(kept)
    end
  end
end
