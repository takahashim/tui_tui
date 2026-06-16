# frozen_string_literal: true

require_relative "display_text"
require_relative "style"
require_relative "rect"
require_relative "modal"
require_relative "key_intent"

module TuiTui
  # Scrollable read-only text modal.
  class Pager < Modal
    MARGIN = 2
    WHEEL = 3

    def initialize(title, lines, start: 0, close_keys: [], theme: Theme::DEFAULT)
      @title = title
      @lines = lines.map { |line| DisplayText.new(line) }
      @top = start
      @page = 1
      @close_keys = close_keys
      @theme = theme
    end

    def handle(key)
      return :close if @close_keys.include?(key)

      case KeyIntent.for(key)
      when :up
        scroll(-1)
      when :down
        scroll(1)
      when :top
        scroll(-@lines.size)
      when :bottom
        scroll(@lines.size)
      when :cancel
        :close
      else
        paginate(key)
      end
    end

    def handle_mouse(event)
      scroll(event.button == :wheel_up ? -WHEEL : WHEEL) if event.action == :wheel
    end

    def draw(canvas, size)
      width = [size.cols - (MARGIN * 2), 20].max
      height = [size.rows - (MARGIN * 2), 5].max
      rect = Rect.centered(size, cols: width, rows: height)
      canvas.frame(rect, style: theme.frame)

      inner = width - 4
      body = [height - 4, 1].max
      @page = body
      clamp(body)

      canvas.text(rect.row + 1, rect.col + 2, DisplayText.new(title_line(body)).truncate(inner), theme.title)
      body.times do |offset|
        line = @lines[@top + offset]
        next if line.nil?

        canvas.text(rect.row + 3 + offset, rect.col + 2, line.truncate(inner), theme.muted)
      end

      canvas
    end

    private

    def paginate(key)
      case key
      when " ", :pgdn
        scroll(@page)
      when "b", :pgup
        scroll(-@page)
      end
    end

    def scroll(delta)
      @top += delta
      nil
    end

    def clamp(body)
      @top = @top.clamp(0, [@lines.size - body, 0].max)
    end

    def title_line(body)
      last = [@top + body, @lines.size].min
      "#{@title}  (#{@top + 1}-#{last}/#{@lines.size})"
    end
  end
end
