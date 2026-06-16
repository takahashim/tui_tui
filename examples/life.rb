#!/usr/bin/env ruby
# frozen_string_literal: true

# Conway's Game of Life: a tick-driven, full-screen cellular automaton with no
# widgets and no domain. It shows TuiTui's renderer under heavy load — every
# generation repaints many cells, and the CanvasCompositor only writes the rows
# that changed — plus `wants_tick?` animation. Cells are a space in a background
# color (ASCII-only, N7). The grid is toroidal (wraps at the edges).
#
#   ruby examples/life.rb
#
# Mouse: click or drag to add cells (right-drag removes) — pause to draw a pattern.
# Keys: Space pause/resume, s single-step (while paused), +/- speed (generations
# per frame), r reseed, q quit. Rendering runs at ~60 fps (tick 1/60); a frame —
# step + view + diff — measures well under the 16 ms budget even on a large, dense
# board, so the CPU is not the limit. +/- accelerates the simulation (more
# generations per frame) without redrawing more often.

require "set"
require_relative "../lib/tui_tui"

module LifeSample
  CELL = TuiTui::Style.new(bg: :green)
  BAR = TuiTui::Style.new(attrs: [:reverse])
  GLIDER = [[0, 1], [1, 2], [2, 0], [2, 1], [2, 2]].freeze

  class Life
    def initialize(rows: 24, cols: 80)
      @rows = rows
      @cols = cols
      @paused = false
      @gen = 0
      @speed = 1 # generations advanced per tick (render stays one frame per tick)
      reseed
    end

    # Idle while paused; otherwise the Runtime ticks us to advance generations.
    def wants_tick? = !@paused

    def update(event)
      case event
      when TuiTui::KeyEvent then handle_key(event.key)
      when TuiTui::MouseEvent then handle_mouse(event)
      when TuiTui::ResizeEvent then resize(event.size)
      when TuiTui::TickEvent then advance
      else self
      end
    end

    def view(size)
      @rows = size.rows
      @cols = size.cols
      canvas = TuiTui::Canvas.blank(size)
      @alive.each do |(row, col)|
        canvas.text(row, col, " ", CELL) if row.between?(1, size.rows - 1) && col.between?(1, size.cols)
      end
      draw_status(canvas, size)
      canvas
    end

    private

    def handle_key(key)
      case key
      when "q", TuiTui::KeyCode::CTRL_C then return :quit
      when " " then @paused = !@paused
      when "s" then step if @paused # single-step
      when "r" then reseed
      when "+", "=" then @speed += 1
      when "-", "_" then @speed = [@speed - 1, 1].max
      end
      self
    end

    def resize(size)
      @rows = size.rows
      @cols = size.cols
      self
    end

    # Click or drag to bring cells to life (right button kills them). Pause first
    # to draw a pattern; while running a lone cell dies next generation, as Life
    # demands. The status row is left alone.
    def handle_mouse(event)
      return self unless %i[press drag].include?(event.action)
      return self unless event.row.between?(1, @rows - 1)

      cell = [event.row, event.col]
      event.button == :right ? @alive.delete(cell) : @alive.add(cell)
      self
    end

    # Render is one frame per tick; the simulation runs `@speed` generations in
    # between, which decouples animation speed from the render frame rate.
    def advance
      @speed.times { step }
      self
    end

    # One generation (B3/S23) on a toroidal grid: a cell lives next gen with 3
    # live neighbors, or 2 if already alive.
    def step
      counts = Hash.new(0)
      @alive.each { |(r, c)| neighbors(r, c).each { |cell| counts[cell] += 1 } }
      @alive = counts.filter_map { |cell, n| cell if n == 3 || (n == 2 && @alive.include?(cell)) }.to_set
      @gen += 1
    end

    def neighbors(row, col)
      result = []
      (-1..1).each do |dr|
        (-1..1).each do |dc|
          next if dr.zero? && dc.zero?

          result << [(row + dr - 1) % @rows + 1, (col + dc - 1) % @cols + 1]
        end
      end
      result
    end

    # Scatter a few gliders so there is immediate, visible motion.
    def reseed
      @gen = 0
      @alive = Set.new
      [[3, 3], [3, 30], [12, 50], [16, 10]].each { |r0, c0| place(GLIDER, r0, c0) }
    end

    def place(pattern, row0, col0)
      pattern.each { |dr, dc| @alive << [((row0 + dr - 1) % @rows) + 1, ((col0 + dc - 1) % @cols) + 1] }
    end

    def draw_status(canvas, size)
      state = @paused ? "paused" : "running"
      text = " gen #{@gen}  (#{@alive.size} alive, #{state}, #{@speed}x)  " \
             "click=draw  Space=pause  s=step  +/-=speed  r=reseed  q=quit"
      rect = TuiTui::Rect.new(row: size.rows, col: 1, rows: 1, cols: size.cols)
      TuiTui::StatusBar.draw(canvas, rect, left: text, style: BAR)
    end
  end
end

if $PROGRAM_NAME == __FILE__
  TuiTui::Runtime.new(LifeSample::Life.new).run(tick: 1.0 / 60) # ~60 fps render
end
