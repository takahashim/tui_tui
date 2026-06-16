# frozen_string_literal: true

module TuiTui
  # Cursor and viewport arithmetic shared by list-like widgets.
  class ScrollList
    attr_reader :cursor, :top

    def initialize(count = 0)
      @count = count
      @cursor = 0
      @top = 0
    end

    def count=(value)
      @count = [value, 0].max
      @cursor = @cursor.clamp(0, last)
    end

    attr_reader :count

    def empty? = @count.zero?
    def last = [@count - 1, 0].max
    def at_end? = @cursor == last

    def move(delta) = go_to(@cursor + delta)
    def page(height) = move(height)
    def to_top = go_to(0)
    def to_end = go_to(last)

    def go_to(index)
      @cursor = index.clamp(0, last)
      self
    end

    def ensure_visible(height)
      return self if height <= 0

      @top = @cursor if @cursor < @top
      @top = @cursor - height + 1 if @cursor >= @top + height
      @top = 0 if @top.negative?
      self
    end

    def each_visible(height)
      return enum_for(:each_visible, height) unless block_given?

      height.times do |offset|
        index = @top + offset
        break if index >= @count

        yield index, offset
      end

      self
    end
  end
end
