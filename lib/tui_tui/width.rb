# frozen_string_literal: true

module TuiTui
  # Terminal column width for the Unicode ranges this renderer needs.
  # Wide/fullwidth clusters are 2, combining/control clusters are 0.
  module Width
    WIDE = [
      # Hangul Jamo
      [0x1100, 0x115F],
      # CJK radicals, Kangxi, CJK symbols & punctuation
      [0x2E80, 0x303E],
      # Hiragana, Katakana, CJK symbols, enclosed CJK, ...
      [0x3041, 0x33FF],
      # CJK Unified Ext A
      [0x3400, 0x4DBF],
      # CJK Unified Ideographs
      [0x4E00, 0x9FFF],
      # Yi
      [0xA000, 0xA4CF],
      # Hangul Jamo Ext A
      [0xA960, 0xA97F],
      # Hangul Syllables
      [0xAC00, 0xD7A3],
      # CJK Compatibility Ideographs
      [0xF900, 0xFAFF],
      # Vertical forms
      [0xFE10, 0xFE19],
      # CJK Compatibility / small forms
      [0xFE30, 0xFE6F],
      # Fullwidth forms
      [0xFF00, 0xFF60],
      # Fullwidth signs
      [0xFFE0, 0xFFE6],
      # Kana supplement / extended
      [0x1B000, 0x1B16F],
      # Regional indicator symbols (flag letters)
      [0x1F1E6, 0x1F1FF],
      # Enclosed ideographic supplement
      [0x1F200, 0x1F251],
      # Misc symbols & pictographs + emoticons
      [0x1F300, 0x1F64F],
      # Transport & map symbols
      [0x1F680, 0x1F6FF],
      # Supplemental symbols & pictographs
      [0x1F900, 0x1F9FF],
      # Symbols & pictographs extended-A
      [0x1FA70, 0x1FAFF],
      # CJK Unified Ext B and beyond
      [0x20000, 0x3FFFD]
    ].freeze

    ZERO = [
      # Combining diacritical marks
      [0x0300, 0x036F],
      [0x0483, 0x0489],
      [0x0591, 0x05BD],
      [0x0610, 0x061A],
      [0x064B, 0x065F],
      [0x06D6, 0x06DC],
      # Zero-width space / joiners / marks
      [0x200B, 0x200F],
      # Variation selectors
      [0xFE00, 0xFE0F],
      # Zero-width no-break space (BOM)
      [0xFEFF, 0xFEFF],
      # Emoji skin-tone modifiers (combine onto the base)
      [0x1F3FB, 0x1F3FF]
    ].freeze

    class << self

      def cluster(grapheme)
        # A cluster's base codepoint determines its terminal width.
        base = grapheme[0]
        return 1 if control?(base.ord)

        char(base)
      end

      def char(char)
        cp = char.ord
        return 0 if control?(cp)
        return 0 if in?(cp, ZERO)

        in?(cp, WIDE) ? 2 : 1
      end

      def control?(cp)
        cp < 0x20 || cp == 0x7F || cp.between?(0x80, 0x9F)
      end

      private

      def in?(cp, ranges)
        # Ranges are sorted and non-overlapping, so one binary search is enough.
        index = ranges.bsearch_index { |_lo, hi| hi >= cp }
        !index.nil? && ranges[index][0] <= cp
      end
    end
  end
end
