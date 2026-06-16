#!/usr/bin/env ruby
# frozen_string_literal: true

# A small but usable todo list. It demonstrates a typical TuiTui app shape:
# a ScrollList-backed main view, styled rows built from Line/Span, modal widgets
# for add/edit/delete/help, and width-safe rendering for Japanese text.
#
#   ruby examples/todo.rb
#
# Keys: j/k (or ↑/↓) move, Space toggle, a add, e edit, d delete, f filter,
# c clear filter, ? help, q (or Ctrl-C) quit.

require_relative "../lib/tui_tui"

module TodoSample
  Todo = Data.define(:title, :done)

  S = TuiTui::Style
  STYLE = {
    title: S.new(attrs: [:bold]),
    dim: S.new(attrs: [:dim]),
    done: S.new(fg: :green),
    pending: S.new(fg: :yellow),
    select: S.new(attrs: [:reverse]),
    select_pending: S.new(fg: :yellow, attrs: [:reverse]),
    select_done: S.new(fg: :green, attrs: [:reverse]),
    empty: S.new(fg: :bright_black, attrs: [:italic]),
    filter: S.new(fg: :cyan, attrs: [:bold]),
  }.freeze

  HELP = [
    ["j / k  ↑ / ↓", "move"],
    ["Space", "toggle done"],
    ["a", "add a todo"],
    ["e", "edit selected todo"],
    ["d", "delete selected todo"],
    ["f", "filter by text"],
    ["c", "clear filter"],
    ["g / G", "top / bottom"],
    ["?", "this help"],
    ["q", "quit"],
  ].freeze

  SEED = [
    Todo.new("Add a useful example", false),
    Todo.new("Keep rendering width-safe", true),
    Todo.new("日本語のタスクも崩れない", false),
  ].freeze

  class App
    def initialize(todos = SEED)
      @todos = todos.dup
      @list = TuiTui::ScrollList.new
      @filter = ""
      @modal = nil
      @on_result = nil
      @toast = nil
      sync_list
    end

    # Keep ticking only while a toast is showing, so it auto-dismisses.
    def wants_tick? = !@toast.nil?

    def update(event)
      @toast = nil if @toast&.expired?
      return self unless event.is_a?(TuiTui::KeyEvent)
      return route_modal(event.key) if @modal

      handle_key(event.key)
    end

    def view(size)
      canvas = TuiTui::Canvas.blank(size)
      body_rows = [size.rows - 4, 1].max
      body = TuiTui::Rect.new(row: 3, col: 2, rows: body_rows, cols: [size.cols - 2, 1].max)

      draw_header(canvas, size)
      draw_list(canvas, body)
      draw_status(canvas, size)
      @toast&.draw(canvas, size, style: STYLE[:select])
      @modal&.draw(canvas, size)
      canvas
    end

    private

    def toast(message) = @toast = TuiTui::Toast.new(message)

    def handle_key(key)
      case key
      when "q", TuiTui::KeyCode::CTRL_C then return :quit
      when "?" then open_modal(TuiTui::Help.new("Todo keys", HELP)) { nil }
      when "a" then prompt_add
      when "e" then prompt_edit
      when "d" then confirm_delete
      when "f" then prompt_filter
      when "c" then clear_filter
      when " ", "\r" then toggle
      when "j", :down then @list.move(1)
      when "k", :up then @list.move(-1)
      when "g", :home then @list.to_top
      when "G", :end then @list.to_end
      end
      self
    end

    def open_modal(widget, &on_result)
      @modal = widget
      @on_result = on_result
    end

    def route_modal(key)
      result = @modal.handle(key)
      return self if result.nil?

      @modal = nil
      @on_result.call(result)
      sync_list
      self
    end

    def prompt_add
      open_modal(TuiTui::Prompt.new("New todo:")) do |result|
        next unless result.is_a?(Array) && result.first == :ok

        title = result.last.strip
        next if title.empty?

        @todos << Todo.new(title, false)
        toast("added: #{title}")
      end
    end

    def prompt_edit
      index = selected_index
      return unless index

      open_modal(TuiTui::Prompt.new("Edit todo:", value: @todos[index].title)) do |result|
        next unless result.is_a?(Array) && result.first == :ok

        title = result.last.strip
        next if title.empty?

        @todos[index] = @todos[index].with(title: title)
        toast("updated")
      end
    end

    def prompt_filter
      open_modal(TuiTui::Prompt.new("Filter:", value: @filter)) do |result|
        next unless result.is_a?(Array) && result.first == :ok

        @filter = result.last.strip
      end
    end

    def confirm_delete
      index = selected_index
      return unless index

      title = TuiTui::DisplayText.new(@todos[index].title).truncate(30)
      open_modal(TuiTui::Confirm.new("Delete #{title}?", ok: "Delete")) do |result|
        next unless result == :ok

        @todos.delete_at(index)
        toast("deleted")
      end
    end

    def clear_filter
      @filter = ""
      sync_list
    end

    def toggle
      index = selected_index
      return unless index

      todo = @todos[index]
      @todos[index] = todo.with(done: !todo.done)
      toast(todo.done ? "reopened" : "done")
    end

    def draw_header(canvas, size)
      canvas.text(1, 2, "Todo list", STYLE[:title])
      if @filter.empty?
        canvas.text(1, 14, "#{open_count} open / #{@todos.size} total", STYLE[:dim])
      else
        canvas.text(1, 14, "filter: #{@filter}", STYLE[:filter])
      end
      canvas.hline(2, 1, size.cols, "-", STYLE[:dim])
    end

    def draw_list(canvas, rect)
      sync_list
      if visible.empty?
        message = @filter.empty? ? "No todos. Press a to add one." : "No matches. Press c to clear the filter."
        canvas.text(rect.row, rect.col, message, STYLE[:empty])
        return
      end

      TuiTui::List.new(@list).draw(canvas, rect, highlight: STYLE[:select]) do |visible_index, selected|
        todo = @todos[visible[visible_index]]
        row_line(todo, selected)
      end
    end

    def row_line(todo, selected)
      marker = todo.done ? "[x] " : "[ ] "
      state = row_state(todo, selected)
      text = todo.done ? STYLE[:dim] : nil

      TuiTui::Line[
        TuiTui::Span[marker, state],
        TuiTui::Span[todo.title, selected ? STYLE[:select] : text],
      ]
    end

    def row_state(todo, selected)
      return todo.done ? STYLE[:select_done] : STYLE[:select_pending] if selected

      todo.done ? STYLE[:done] : STYLE[:pending]
    end

    def draw_status(canvas, size)
      status = " a add   e edit   d delete   f filter   Space toggle   ? help   q quit"
      canvas.hline(size.rows - 1, 1, size.cols, "-", STYLE[:dim]) if size.rows > 1
      canvas.text(size.rows, 1, status, STYLE[:dim])
    end

    def selected_index = visible[@list.cursor]

    def visible
      return (0...@todos.size).to_a if @filter.empty?

      needle = @filter.downcase
      @todos.each_index.select { |index| @todos[index].title.downcase.include?(needle) }
    end

    def sync_list
      @list.count = visible.size
    end

    def open_count = @todos.count { |todo| !todo.done }
  end
end

if $PROGRAM_NAME == __FILE__
  TuiTui::Runtime.new(TodoSample::App.new).run
end
