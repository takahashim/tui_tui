# frozen_string_literal: true

require_relative "event"
require_relative "key_reader"

module TuiTui
  # Converts terminal input readiness and resize notifications into runtime events.
  class EventStream
    def initialize(input:, size:)
      @input = input
      @size = size
      @key_reader = KeyReader.new
      @resized = false
      @queue = []
    end

    def resized!
      @resized = true
    end

    def next_event(tick: 0.1)
      return @queue.shift unless @queue.empty?

      if @resized
        @resized = false
        return ResizeEvent.new(size: @size.size)
      end

      ready = IO.select([@input], nil, nil, tick)
      return TickEvent.new unless ready

      raw = @key_reader.read_all(@input)
      return EofEvent.new if raw.nil?

      @queue.concat(raw.map { |event| event.is_a?(MouseEvent) ? event : KeyEvent.new(key: event) })
      @queue.shift
    end
  end
end
