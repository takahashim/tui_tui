# frozen_string_literal: true

module TuiTui
  # Query-prepared subsequence matcher used to rank many candidates consistently.
  class Fuzzy
    Match = Data.define(:score, :positions)

    BOUNDARY = "/\\_-. ".freeze

    def initialize(query)
      @query = query.to_s.downcase.grapheme_clusters
    end

    def match(string)
      return Match.new(score: 0, positions: []) if @query.empty?

      haystack = string.downcase.grapheme_clusters
      positions = []
      from = 0
      @query.each do |grapheme|
        at = (from...haystack.size).find { |i| haystack[i] == grapheme } or return nil

        positions << at
        from = at + 1
      end

      Match.new(score: score(haystack, positions), positions: positions)
    end

    def rank(candidates)
      candidates
        .filter_map do |item|
          found = match(block_given? ? yield(item) : item)
          [item, found] if found
        end
        .sort_by { |(_item, found)| -found.score }
    end

    private

    def score(graphemes, positions)
      total = 0
      positions.each_with_index do |pos, i|
        total += 10
        total += 6 if i.positive? && positions[i - 1] == pos - 1
        total += 8 if boundary?(graphemes, pos)
      end

      total - (positions.last - positions.first)
    end

    def boundary?(graphemes, pos)
      pos.zero? || BOUNDARY.include?(graphemes[pos - 1])
    end
  end
end
