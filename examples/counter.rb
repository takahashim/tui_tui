#!/usr/bin/env ruby
# frozen_string_literal: true

# The smallest possible TuiTui app: a counter. It shows the whole contract and
# nothing else — `view(size) -> Canvas` and `update(event) -> self | :quit` —
# with no widgets and no layout.
#
#   ruby examples/counter.rb
#
# Keys: j / + / ↑ increment, k / - / ↓ decrement, r reset, q (or Ctrl-C) quit.

require_relative "../lib/tui_tui"

module CounterSample
  BIG = TuiTui::Style.new(fg: :green, attrs: [:bold])
  HINT = TuiTui::Style.new(attrs: [:dim])

  class Counter
    def initialize
      @count = 0
    end

    def update(event)
      return self unless event.is_a?(TuiTui::KeyEvent)

      case event.key
      when "q", TuiTui::KeyCode::CTRL_C then return :quit
      when "j", "+", :up then @count += 1
      when "k", "-", :down then @count -= 1
      when "r" then @count = 0
      end
      self
    end

    def view(size)
      canvas = TuiTui::Canvas.blank(size)
      label = "count: #{@count}"
      box = TuiTui::Rect.centered(size, cols: TuiTui::DisplayText.new(label).width, rows: 1)
      canvas.text(box.row, box.col, label, BIG)
      canvas.text(size.rows, 1, " j/+ up   k/- down   r reset   q quit", HINT)
      canvas
    end
  end
end

if $PROGRAM_NAME == __FILE__
  TuiTui::Runtime.new(CounterSample::Counter.new).run
end
