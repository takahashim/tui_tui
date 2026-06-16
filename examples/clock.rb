#!/usr/bin/env ruby
# frozen_string_literal: true

# Shows the tick seam: a big, resizable, always-animating clock. The app opts in
# to timer ticks with `wants_tick?`; the Runtime delivers a TickEvent on its poll
# interval and re-renders, so it animates without input. The time is drawn as
# large digits — each font pixel is an N-cell block of background color, so the
# banner is ASCII-only (N7), no block-drawing glyphs. The size auto-fits the
# terminal and is adjustable with +/-.
#
#   ruby examples/clock.rb
#
# Keys: + / - bigger / smaller, q (or Ctrl-C) quit.

require_relative "../lib/tui_tui"

module ClockSample
  TIME = TuiTui::Style.new(bg: :cyan) # a lit "pixel" of the big digits
  HINT = TuiTui::Style.new(attrs: [:dim])
  SPINNER = %w[| / - \\].freeze

  GLYPH_W = 3 # font cells wide
  GLYPH_H = 5 # font cells tall

  # 3x5 ASCII fonts; "#" is a lit pixel, " " is blank.
  FONT = {
    "0" => ["###", "# #", "# #", "# #", "###"],
    "1" => ["  #", "  #", "  #", "  #", "  #"],
    "2" => ["###", "  #", "###", "#  ", "###"],
    "3" => ["###", "  #", "###", "  #", "###"],
    "4" => ["# #", "# #", "###", "  #", "  #"],
    "5" => ["###", "#  ", "###", "  #", "###"],
    "6" => ["###", "#  ", "###", "# #", "###"],
    "7" => ["###", "  #", "  #", "  #", "  #"],
    "8" => ["###", "# #", "###", "# #", "###"],
    "9" => ["###", "# #", "###", "  #", "###"],
    ":" => ["   ", " # ", "   ", " # ", "   "],
  }.freeze

  class Clock
    def initialize
      @ticks = 0
      @scale = nil # set to the auto-fit size on first view; adjusted with +/-
    end

    def wants_tick? = true

    def update(event)
      case event
      when TuiTui::KeyEvent then handle_key(event.key)
      when TuiTui::TickEvent then (@ticks += 1) && self
      else self
      end
    end

    def view(size)
      canvas = TuiTui::Canvas.blank(size)
      time = Time.now.strftime("%H:%M:%S")
      @scale = (@scale || max_scale(size, time)).clamp(1, max_scale(size, time))
      box = TuiTui::Rect.centered(size, cols: banner_width(time, @scale), rows: banner_height(@scale))
      draw_big(canvas, box.row, box.col, time, @scale)
      canvas.text(size.rows, 1, " #{SPINNER[@ticks % SPINNER.length]}  +/- size  q quit", HINT)
      canvas
    end

    private

    def handle_key(key)
      case key
      when "q", TuiTui::KeyCode::CTRL_C then return :quit
      when "+", "=" then @scale += 1 # clamped to fit in view
      when "-", "_" then @scale -= 1
      end
      self
    end

    # A font pixel is `2*scale` columns by `scale` rows (≈ square on screen, since
    # terminal cells are about twice as tall as wide); glyphs sit `2*scale` apart.
    def banner_width(text, scale) = (text.length * GLYPH_W + (text.length - 1)) * 2 * scale
    def banner_height(scale) = GLYPH_H * scale

    # The largest scale whose banner still fits the terminal (at least 1).
    def max_scale(size, text)
      by_width = size.cols / banner_width(text, 1)
      by_height = (size.rows - 1) / GLYPH_H
      [[by_width, by_height].min, 1].max
    end

    def draw_big(canvas, top, left, text, scale)
      pixel_w = 2 * scale
      col = left
      text.each_char do |ch|
        glyph = FONT[ch]
        next unless glyph

        glyph.each_with_index do |line, r|
          line.each_char.with_index do |pixel, c|
            next unless pixel == "#"

            cell = TuiTui::Rect.new(row: top + (r * scale), col: col + (c * pixel_w), rows: scale, cols: pixel_w)
            canvas.fill(cell, TIME)
          end
        end
        col += (GLYPH_W * pixel_w) + (2 * scale)
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  TuiTui::Runtime.new(ClockSample::Clock.new).run(tick: 0.1)
end
