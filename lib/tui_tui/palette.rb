# frozen_string_literal: true

module TuiTui
  # Color math for downgrading 256-color and RGB values to ANSI-16.
  class Palette
    ANSI16 = [
      [[0, 0, 0], 30],
      [[205, 0, 0], 31],
      [[0, 205, 0], 32],
      [[205, 205, 0], 33],
      [[0, 0, 238], 34],
      [[205, 0, 205], 35],
      [[0, 205, 205], 36],
      [[229, 229, 229], 37],
      [[127, 127, 127], 90],
      [[255, 0, 0], 91],
      [[0, 255, 0], 92],
      [[255, 255, 0], 93],
      [[92, 92, 255], 94],
      [[255, 0, 255], 95],
      [[0, 255, 255], 96],
      [[255, 255, 255], 97]
    ].freeze

    def nearest_code(rgb)
      ANSI16.min_by { |color, _code| distance(color, rgb) }.last
    end

    def rgb_from_256(index)
      return ANSI16[index].first if index < 16

      if index <= 231
        i = index - 16
        [cube(i / 36), cube((i % 36) / 6), cube(i % 6)]
      else
        v = 8 + (10 * (index - 232))
        [v, v, v]
      end
    end

    private

    def cube(step) = step.zero? ? 0 : (55 + (40 * step))

    def distance(a, b)
      (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2
    end
  end
end
