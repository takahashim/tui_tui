# frozen_string_literal: true

require_relative "display_text"
require_relative "style"
require_relative "scroll_list"
require_relative "list"
require_relative "line"
require_relative "span"
require_relative "rect"
require_relative "modal"
require_relative "key_intent"

module TuiTui
  # Scrollable list picker modal.
  class Select < Modal
    MAX_ROWS = 12
    MIN_INNER = 16
    WHEEL = 3

    def initialize(title, items, default: 0, theme: Theme::DEFAULT)
      @title = DisplayText.new(title)
      @items = items.map { |item| DisplayText.new(item) }
      @list = ScrollList.new(@items.size)
      @list.go_to(default)
      @theme = theme
    end

    def cursor = @list.cursor

    def handle(key)
      case KeyIntent.for(key)
      when :up
        nudge(-1)
      when :down
        nudge(1)
      when :top
        nudge_to(0)
      when :bottom
        nudge_to(@list.last)
      when :cancel
        :cancel
      else
        @list.cursor if ["\r", " "].include?(key)
      end
    end

    # Wheel moves the highlighted item; a click on an item picks it. Returns the
    # chosen index on a click, otherwise nil (stay open).
    def handle_mouse(event)
      case event.action
      when :wheel
        nudge(event.button == :wheel_up ? -WHEEL : WHEEL)
      when :press
        click(event)
      end
    end

    def draw(canvas, size)
      rows = visible_rows(size)
      inner = [MIN_INNER, @title.width, *@items.map(&:width)].max
      rect, text_col = panel(canvas, inner: inner, body_rows: rows + 2)

      canvas.text(rect.row + 1, text_col, @title.truncate(inner), theme.title)
      draw_items(canvas, rect.row + 3, text_col, inner, rows)
      canvas
    end

    private

    def nudge(delta)
      @list.move(delta)
      nil
    end

    def nudge_to(index)
      @list.go_to(index)
      nil
    end

    def visible_rows(size)
      room = [size.rows - 4, 1].max
      [@items.size, MAX_ROWS, room].min
    end

    def draw_items(canvas, row, col, inner, rows)
      @items_rect = Rect.new(row: row, col: col, rows: rows, cols: inner)
      List.new(@list).draw(canvas, @items_rect) do |index, focused|
        Line[Span[@items[index].to_s, focused ? theme.selection : theme.text]]
      end
    end

    # The item under a click, picked, or nil if the click missed the list.
    def click(event)
      return nil unless @items_rect

      index = List.new(@list).index_at(@items_rect, event)
      return nil if index.nil?

      @list.go_to(index)
      @list.cursor
    end
  end
end
