# frozen_string_literal: true

require_relative "display_text"
require_relative "style"
require_relative "clock"

module TuiTui
  # A transient notification overlay.
  # The clock is injectable so expiry is testable without sleeping.
  class Toast
    DEFAULT_SECONDS = 2.0
    DEFAULT_STYLE = Style.new(attrs: [:reverse])
    DEFAULT_POSITION = :bottom_center
    POSITIONS = {
      top_left: [:top, :left],
      top_center: [:top, :center],
      top_right: [:top, :right],
      middle_left: [:middle, :left],
      middle_center: [:middle, :center],
      middle_right: [:middle, :right],
      bottom_left: [:bottom, :left],
      bottom_center: [:bottom, :center],
      bottom_right: [:bottom, :right],
      center: [:middle, :center]
    }.freeze
    MONOTONIC = -> { Clock.monotonic }

    def initialize(message, seconds: DEFAULT_SECONDS, position: DEFAULT_POSITION, clock: MONOTONIC)
      @message = DisplayText.new(message)
      @position = position
      @clock = clock
      @expires_at = clock.call + seconds
      validate_position!
    end

    def expired? = @clock.call >= @expires_at

    def draw(canvas, size, style: DEFAULT_STYLE, position: @position)
      return canvas if expired?

      label = DisplayText.new(" #{@message} ").truncate(size.cols)
      vertical, horizontal = position_parts(position)
      row = row_for(size, vertical)
      col = col_for(size, label.width, horizontal)
      canvas.text(row, col, label, style)
      canvas
    end

    private

    def validate_position!
      position_parts(@position)
    end

    def position_parts(position)
      POSITIONS.fetch(position) do
        raise ArgumentError, "unknown toast position: #{position.inspect}"
      end
    end

    def row_for(size, vertical)
      case vertical
      when :top
        1
      when :middle
        ((size.rows + 1) / 2).clamp(1, size.rows)
      when :bottom
        [size.rows - 2, 1].max
      end
    end

    def col_for(size, width, horizontal)
      case horizontal
      when :left
        1
      when :center
        [((size.cols - width) / 2) + 1, 1].max
      when :right
        [size.cols - width + 1, 1].max
      end
    end
  end
end
