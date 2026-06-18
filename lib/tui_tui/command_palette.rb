# frozen_string_literal: true

require_relative "display_text"
require_relative "text_sanitizer"
require_relative "style"
require_relative "scroll_list"
require_relative "list"
require_relative "line"
require_relative "span"
require_relative "rect"
require_relative "modal"
require_relative "fuzzy"
require_relative "key_code"

module TuiTui
  # Fuzzy-filtered command palette modal (think Ctrl-P): type to narrow a list of
  # commands, arrows or Ctrl-N/Ctrl-P to move, Enter to pick, Esc to cancel.
  #
  # Items are arbitrary objects; pass a block to derive each one's display label
  # (defaults to #to_s). Resolves to the chosen item on Enter and :cancel on
  # escape; stays open (nil) while the query has no matches.
  #
  #   host.open(CommandPalette.new(commands) { |c| c.title }) { |cmd| cmd.run; self }
  class CommandPalette < Modal
    MAX_ROWS = 10
    MIN_INNER = 28
    WHEEL = 3

    def initialize(items, prompt: "> ", placeholder: "Type to search…", theme: Theme::DEFAULT, &label)
      @items = items.to_a
      @label = label || :to_s.to_proc
      @prompt = DisplayText.new(prompt)
      @placeholder = DisplayText.new(placeholder)
      @theme = theme
      @graphemes = []
      @list = ScrollList.new(0)
      refilter
    end

    def query = @graphemes.join

    # The original item under the cursor, or nil when nothing matches.
    def selection = @filtered[@list.cursor]&.first

    def handle(key)
      case key
      when "\r"
        selection
      when :escape, KeyCode::CTRL_C
        :cancel
      when :up, KeyCode::CTRL_P
        move(-1)
      when :down, KeyCode::CTRL_N
        move(1)
      when :home
        move_to(0)
      when :end
        move_to(@list.last)
      when KeyCode::BACKSPACE, :backspace
        edit { @graphemes.pop }
      when String
        edit { @graphemes.concat(key.grapheme_clusters) if TextSanitizer.printable?(key) }
      end
    end

    # Wheel scrolls the highlight; a click on a row picks it (returns the item),
    # otherwise nil to stay open.
    def handle_mouse(event)
      case event.action
      when :wheel
        move(event.button == :wheel_up ? -WHEEL : WHEEL)
      when :press
        click(event)
      end
    end

    def draw(canvas, size)
      rows = visible_rows(size)
      inner = [MIN_INNER, *@filtered.map { |_item, label, _pos| label.width }].max
      rect, col = panel(canvas, inner: inner, body_rows: rows + 2)

      draw_query(canvas, rect.row + 1, col, inner)
      draw_items(canvas, rect.row + 3, col, inner, rows)
      canvas
    end

    private

    def move(delta)
      @list.move(delta)
      nil
    end

    def move_to(index)
      @list.go_to(index)
      nil
    end

    # Apply a query edit, then refilter. Returns nil so the modal stays open.
    def edit
      yield
      refilter
      nil
    end

    # Recompute the visible list: fuzzy-ranked (best first, with matched positions
    # for highlighting) while querying, otherwise the items in their given order.
    # Each entry is [item, DisplayText(label), positions]; the cursor resets so a
    # narrowed query always lands on the top match.
    def refilter
      @filtered =
        if @graphemes.empty?
          @items.map { |item| [item, label_text(item), []] }
        else
          Fuzzy.new(query).rank(@items) { |item| @label.call(item).to_s }
               .map { |item, found| [item, label_text(item), found.positions] }
        end
      @list.count = @filtered.size
      @list.go_to(0)
    end

    def label_text(item) = DisplayText.new(@label.call(item).to_s)

    def visible_rows(size)
      room = [size.rows - 4, 1].max
      [[@filtered.size, 1].max, MAX_ROWS, room].min
    end

    def draw_query(canvas, row, col, inner)
      canvas.text(row, col, @prompt, theme.accent)
      text_col = col + @prompt.width
      budget = inner - @prompt.width
      if @graphemes.empty?
        canvas.text(row, text_col, @placeholder.truncate(budget), theme.muted)
      else
        canvas.text(row, text_col, DisplayText.new(query).truncate(budget), theme.text)
      end
    end

    def draw_items(canvas, row, col, inner, rows)
      @items_rect = Rect.new(row: row, col: col, rows: rows, cols: inner)
      if @filtered.empty?
        canvas.text(row, col, DisplayText.new("No matches").truncate(inner), theme.muted)
        return
      end

      List.new(@list).draw(canvas, @items_rect, highlight: theme.selection) do |index, focused|
        _item, label, positions = @filtered[index]
        base = focused ? theme.selection : theme.text
        # Keep the focused row a single style; highlight matches with accent only
        # on unfocused rows so the selection bar stays legible.
        match = focused ? base : theme.accent
        styled_line(label.to_s, positions, base, match)
      end
    end

    # The label as a Line with matched graphemes in `match` and the rest in `base`;
    # runs of the same style coalesce into one Span (grapheme indices line up with
    # Fuzzy#positions).
    def styled_line(label, positions, base, match)
      return Line[Span[label, base]] if positions.empty?

      spans = []
      run = +""
      run_style = nil
      label.grapheme_clusters.each_with_index do |grapheme, i|
        style = positions.include?(i) ? match : base
        if style != run_style && !run.empty?
          spans << Span[run, run_style]
          run = +""
        end
        run_style = style
        run << grapheme
      end
      spans << Span[run, run_style] unless run.empty?
      Line.new(spans)
    end

    # The item under a click, picked, or nil if the click missed the list.
    def click(event)
      return nil unless @items_rect

      index = List.new(@list).index_at(@items_rect, event)
      return nil if index.nil?

      @list.go_to(index)
      selection
    end
  end
end
