#!/usr/bin/env ruby
# frozen_string_literal: true

# A focus-driven form: fields of several kinds (single-line text, multi-line
# text area, dropdown select, radio list, checkbox group, button) stacked one
# above the next, with one focused at a time. It shows how a TuiTui app composes
# small field widgets of differing (and changing) heights, lays them out by
# accumulating their rows, moves focus with a FocusRing (Tab / arrows, or a
# mouse click), edits text, and validates on submit. The text cursor is the real
# hardware cursor; markers are ASCII (N7): (*) radio, [x] checkbox, v/^ dropdown.
#
#   ruby examples/form.rb
#
# Mouse: click a field — or a specific option / text position — to focus and act.
# Keys: Tab / Shift-Tab move fields, up/down move within a list or text area (and
#       spill to the next/previous field at the edges), left/right & Home/End
#       edit text (Ctrl-A/E line start/end, Ctrl-B/F back/forward, Ctrl-D delete,
#       Ctrl-P/N prev/next line in the text area), Space select/toggle an option,
#       Enter submit (a newline inside the text area), q / Ctrl-C quit.

require_relative "../lib/tui_tui"

module FormSample
  LABEL = TuiTui::Style.new(attrs: [:bold])
  HINT = TuiTui::Style.new(attrs: [:dim])
  MARKER = TuiTui::Style.new(attrs: [:bold])     # the ">" beside the focused field
  ERR = TuiTui::Style.new(fg: :bright_red)
  GOOD = TuiTui::Style.new(fg: :bright_green)
  # Colour-agnostic so it reads on any terminal: the input region is an
  # underline and typed text keeps the default colours. The text cursor is the
  # real hardware cursor (Canvas#cursor_at), so it is always legible and the IME
  # candidate window anchors to the character being edited.
  BOX = TuiTui::Style.new(attrs: [:underline])   # the (empty) input region
  TEXT = TuiTui::Style.new                        # typed text, default colours
  HILITE = TuiTui::Style.new(attrs: [:reverse])   # highlighted list option / button

  CTRL_A = 1.chr   # move to start of line (Emacs/readline bindings)
  CTRL_B = 2.chr   # back one character (like left)
  CTRL_D = 4.chr   # delete the character under the cursor (like Delete)
  CTRL_E = 5.chr   # move to end of line
  CTRL_F = 6.chr   # forward one character (like right)
  CTRL_N = 14.chr  # next line (like down)
  CTRL_P = 16.chr  # previous line (like up)

  TOP = 1          # first field row
  LABEL_COL = 4    # where labels (and list options) start
  OPT_COL = 6      # list options are indented under their label
  VALUE_COL = 18   # where value boxes start
  VALUE_W = 30     # value-box width
  ROLES = ["Engineer", "Designer", "Manager", "その他"].freeze
  CONTACTS = ["Email", "SMS", "Push", "郵送"].freeze
  COUNTRIES = ["日本", "United States", "United Kingdom", "Deutschland", "France", "中国", "한국"].freeze

  # Shared text-editing helpers, so single- and multi-line fields agree on what
  # is printable and how a click column maps to a character index.
  module Text
    module_function

    # No control bytes (Enter/Tab/Esc/Backspace never insert); multibyte passes.
    def printable?(string) = string.bytes.all? { |b| b >= 0x20 && b != 0x7F }

    def width(chars) = TuiTui::DisplayText.new(chars.join).width

    # The character index whose left edge sits closest to `rel_col` columns in —
    # accounting for wide characters before it.
    def column_index(chars, rel_col)
      width = 0
      chars.each_with_index do |ch, i|
        w = TuiTui::DisplayText.new(ch).width
        return i if rel_col < width + ((w + 1) / 2)

        width += w
      end
      chars.length
    end
  end

  # A single editable line. The cursor is a character index, drawn as a bright
  # block at the right column even past wide characters.
  class TextField
    attr_reader :key, :label

    def initialize(key, label, value: "")
      @key = key
      @label = label
      @chars = value.grapheme_clusters # edit by grapheme, so the cursor never lands inside an emoji/combining cluster
      @pos = @chars.length
    end

    def rows = 1
    def value = @chars.join
    def summary = value.empty? ? "(empty)" : value
    def capturing? = true # keys are text, so "q" never quits while editing

    # Returns :submit / :focus_next / :focus_prev to the form, or nil (consumed).
    def handle(key)
      case key
      when "\r" then :submit
      when :down then :focus_next
      when :up then :focus_prev
      when TuiTui::KeyCode::BACKSPACE, :backspace then edit { delete_back }
      when :delete, CTRL_D then edit { @chars.delete_at(@pos) }
      when :left, CTRL_B then edit { @pos = [@pos - 1, 0].max }
      when :right, CTRL_F then edit { @pos = [@pos + 1, @chars.length].min }
      when :home, CTRL_A then edit { @pos = 0 }
      when :end, CTRL_E then edit { @pos = @chars.length }
      when String then edit { insert(key) if Text.printable?(key) }
      end
    end

    def click(_rel_row, col)
      @pos = Text.column_index(@chars, col - VALUE_COL)
      nil
    end

    def draw(canvas, top, focused:)
      canvas.text(top, LABEL_COL, label, LABEL)
      canvas.fill(TuiTui::Rect.new(row: top, col: VALUE_COL, rows: 1, cols: VALUE_W), BOX)
      canvas.text(top, VALUE_COL, TuiTui::DisplayText.new(value).truncate(VALUE_W), TEXT)
      canvas.cursor_at(top, VALUE_COL + Text.width(@chars[0...@pos])) if focused
    end

    private

    def edit
      yield
      nil
    end

    # Re-cluster across the boundary so a combining mark merges into its base.
    def insert(string)
      head = @chars[0...@pos].join
      @chars = (head + string + @chars[@pos..].join).grapheme_clusters
      @pos = (head + string).grapheme_clusters.length
    end

    def delete_back
      return if @pos.zero?

      @chars.delete_at(@pos - 1)
      @pos -= 1
    end
  end

  # A multi-line text box. The buffer is an array of character arrays (one per
  # line); the cursor is a (row, col) pair. Enter splits the current line,
  # Backspace joins lines, arrows navigate and spill focus at the top/bottom
  # edges. Only ROWS_SHOWN lines are visible; the view scrolls to track the
  # cursor. Click to drop the cursor at a position.
  class TextArea
    attr_reader :key, :label

    ROWS_SHOWN = 4

    def initialize(key, label, value: "")
      @key = key
      @label = label
      @lines = value.empty? ? [[]] : value.split("\n", -1).map(&:grapheme_clusters) # one grapheme per element
      @row = @lines.size - 1
      @col = @lines.last.size
      @top = 0 # first visible line
      scroll  # keep the cursor visible even when seeded with a long value
    end

    def rows = ROWS_SHOWN
    def value = @lines.map(&:join).join("\n")
    def summary = value.empty? ? "(empty)" : "#{@lines.size} line(s), #{@lines.sum(&:size)} chars"
    def capturing? = true

    def handle(key)
      case key
      when :up, CTRL_P then @row.zero? ? :focus_prev : move(-1)
      when :down, CTRL_N then @row == @lines.size - 1 ? :focus_next : move(1)
      when :left, CTRL_B then edit { move_left }
      when :right, CTRL_F then edit { move_right }
      when :home, CTRL_A then edit { @col = 0 }
      when :end, CTRL_E then edit { @col = line.size }
      when "\r" then edit { split_line }
      when TuiTui::KeyCode::BACKSPACE, :backspace then edit { backspace }
      when :delete, CTRL_D then edit { delete_forward }
      when String then edit { insert(key) if Text.printable?(key) }
      end
    end

    def click(rel_row, col)
      ln = @top + rel_row
      return nil if ln >= @lines.size

      @row = ln
      @col = Text.column_index(@lines[ln], col - VALUE_COL)
      nil
    end

    def draw(canvas, top, focused:)
      canvas.text(top, LABEL_COL, label, LABEL)
      ROWS_SHOWN.times do |i|
        row = top + i
        canvas.fill(TuiTui::Rect.new(row: row, col: VALUE_COL, rows: 1, cols: VALUE_W), BOX)
        ln = @top + i
        next if ln >= @lines.size

        canvas.text(row, VALUE_COL, TuiTui::DisplayText.new(@lines[ln].join).truncate(VALUE_W), TEXT)
      end
      canvas.cursor_at(top + (@row - @top), VALUE_COL + Text.width(@lines[@row][0...@col])) if focused
    end

    private

    def edit
      yield
      scroll
      nil
    end

    def line = @lines[@row]

    # Move the cursor `delta` rows, keeping the column within the new line.
    def move(delta)
      @row += delta
      @col = [@col, line.size].min
      scroll
      nil
    end

    def move_left
      if @col.positive? then @col -= 1
      elsif @row.positive? then @row -= 1; @col = line.size
      end
    end

    def move_right
      if @col < line.size then @col += 1
      elsif @row < @lines.size - 1 then @row += 1; @col = 0
      end
    end

    def split_line
      tail = line.slice!(@col..) || []
      @lines.insert(@row + 1, tail)
      @row += 1
      @col = 0
    end

    def backspace
      if @col.positive?
        line.delete_at(@col - 1)
        @col -= 1
      elsif @row.positive?
        prev = @lines[@row - 1]
        @col = prev.size
        prev.concat(line)
        @lines.delete_at(@row)
        @row -= 1
      end
    end

    def delete_forward
      if @col < line.size
        line.delete_at(@col)
      elsif @row < @lines.size - 1
        line.concat(@lines.delete_at(@row + 1))
      end
    end

    # Re-cluster the line across the boundary so combining marks merge correctly.
    def insert(string)
      head = line[0...@col].join
      @lines[@row] = (head + string + line[@col..].join).grapheme_clusters
      @col = (head + string).grapheme_clusters.length
    end

    # Keep the cursor line within the visible window.
    def scroll
      @top = @row if @row < @top
      @top = @row - ROWS_SHOWN + 1 if @row >= @top + ROWS_SHOWN
    end
  end

  # A vertical list of mutually-exclusive options — a radio group. up/down move
  # a cursor (spilling at the edges); Space selects the option under it. The
  # cursor (highlight) is kept separate from the selection, so moving around
  # does not change the choice until you press Space.
  class RadioField
    attr_reader :key, :label

    def initialize(key, label, options, index: 0)
      @key = key
      @label = label
      @options = options
      @index = index   # the selected option
      @cursor = index  # the highlighted option
    end

    def rows = 1 + @options.size
    def value = @options[@index]
    def summary = value

    def handle(key)
      case key
      when "\r" then :submit
      when " " then @index = @cursor; nil
      when :up then @cursor.zero? ? :focus_prev : (@cursor -= 1) && nil
      when :down then @cursor == @options.size - 1 ? :focus_next : (@cursor += 1) && nil
      end
    end

    def click(rel_row, _col)
      i = rel_row - 1 # row 0 is the label
      return nil unless i.between?(0, @options.size - 1)

      @cursor = i
      @index = i # a click moves the cursor and selects in one go
      nil
    end

    def draw(canvas, top, focused:)
      canvas.text(top, LABEL_COL, label, LABEL)
      @options.each_with_index do |opt, i|
        mark = i == @index ? "(*)" : "( )"
        style = focused && i == @cursor ? HILITE : (i == @index ? LABEL : HINT)
        canvas.text(top + 1 + i, OPT_COL, "#{mark} #{opt}", style)
      end
    end
  end

  # A vertical list of independent on/off options — a checkbox group. up/down
  # move a cursor (spilling at the edges); Space toggles the option under it.
  class CheckGroupField
    attr_reader :key, :label

    def initialize(key, label, options)
      @key = key
      @label = label
      @options = options
      @checked = Array.new(options.size, false)
      @cursor = 0
    end

    def rows = 1 + @options.size
    def value = @options.each_index.select { |i| @checked[i] }.map { |i| @options[i] }
    def summary = value.empty? ? "(none)" : value.join(", ")

    def handle(key)
      case key
      when "\r" then :submit
      when " " then toggle(@cursor)
      when :up then @cursor.zero? ? :focus_prev : (@cursor -= 1) && nil
      when :down then @cursor == @options.size - 1 ? :focus_next : (@cursor += 1) && nil
      end
    end

    def click(rel_row, _col)
      i = rel_row - 1
      return nil unless i.between?(0, @options.size - 1)

      @cursor = i
      toggle(i)
    end

    def draw(canvas, top, focused:)
      canvas.text(top, LABEL_COL, label, LABEL)
      @options.each_with_index do |opt, i|
        mark = @checked[i] ? "[x]" : "[ ]"
        style = focused && i == @cursor ? HILITE : (@checked[i] ? LABEL : HINT)
        canvas.text(top + 1 + i, OPT_COL, "#{mark} #{opt}", style)
      end
    end

    private

    def toggle(i)
      @checked[i] = !@checked[i]
      nil
    end
  end

  # A dropdown / combo box. Collapsed it shows just the selected value; Space (or
  # a click) opens it into a candidate list, up/down move a cursor, Space/Enter
  # picks (and closes), Escape cancels. While open it grows by `rows` so the form
  # lays the candidates out below it; the form closes it when focus moves away.
  class SelectField
    attr_reader :key, :label

    def initialize(key, label, options, index: 0)
      @key = key
      @label = label
      @options = options
      @index = index   # the selected option
      @cursor = index  # the highlighted option while open
      @open = false
    end

    def rows = @open ? 1 + @options.size : 1
    def value = @options[@index]
    def summary = value
    def capturing? = @open # while open, keys (incl. "q") edit the list, not the app
    def close = @open = false

    def handle(key)
      return handle_open(key) if @open

      case key
      when " " then open
      when "\r" then :submit
      when :up then :focus_prev
      when :down then :focus_next
      end
    end

    def click(rel_row, _col)
      if !@open then open
      elsif rel_row.zero? then close # clicking the header again closes it
      else choose(rel_row - 1)
      end
      nil
    end

    def draw(canvas, top, focused:)
      canvas.text(top, LABEL_COL, label, LABEL)
      style = focused ? HILITE : BOX
      canvas.fill(TuiTui::Rect.new(row: top, col: VALUE_COL, rows: 1, cols: VALUE_W), style)
      canvas.text(top, VALUE_COL, TuiTui::DisplayText.new(value).truncate(VALUE_W - 2), style)
      canvas.text(top, VALUE_COL + VALUE_W - 1, @open ? "^" : "v", style)
      draw_options(canvas, top) if @open
    end

    private

    def open
      @open = true
      @cursor = @index
      nil
    end

    def handle_open(key)
      case key
      when :up then @cursor = [@cursor - 1, 0].max; nil
      when :down then @cursor = [@cursor + 1, @options.size - 1].min; nil
      when " ", "\r" then choose(@cursor); nil
      when :escape then close; nil # cancel: keep the current selection
      end
    end

    def choose(i)
      @index = i if i.between?(0, @options.size - 1)
      close
    end

    def draw_options(canvas, top)
      @options.each_with_index do |opt, i|
        mark = i == @index ? "*" : " "
        style = i == @cursor ? HILITE : HINT
        canvas.text(top + 1 + i, OPT_COL, "#{mark} #{opt}", style)
      end
    end
  end

  # The submit button: Enter / Space (or a click) submits the whole form.
  class Button
    attr_reader :key, :label

    def initialize(key, label)
      @key = key
      @label = label
    end

    def rows = 1
    def summary = nil

    def handle(key)
      case key
      when " ", "\r" then :submit
      when :up then :focus_prev
      when :down then :focus_next
      end
    end

    def click(_rel_row, _col) = :submit

    def draw(canvas, top, focused:)
      canvas.text(top, LABEL_COL, " #{label} ", focused ? HILITE : TEXT)
    end
  end

  class Form
    def initialize
      @fields = [
        TextField.new(:name, "Name"),
        TextField.new(:email, "Email"),
        TextArea.new(:bio, "Bio"),
        SelectField.new(:country, "Country", COUNTRIES),
        RadioField.new(:role, "Role", ROLES),
        CheckGroupField.new(:contact, "Contact via", CONTACTS),
        Button.new(:submit, "[ Submit ]"),
      ]
      @focus = TuiTui::FocusRing.new(@fields.map(&:key))
      @errors = {}
      @done = nil # the success summary once submitted
    end

    def update(event)
      case event
      when TuiTui::KeyEvent then handle_key(event.key)
      when TuiTui::MouseEvent then handle_mouse(event)
      else self
      end
    end

    def view(size)
      canvas = TuiTui::Canvas.blank(size)
      layout.each { |field, top| draw_field(canvas, field, top) }
      draw_footer(canvas, size)
      canvas
    end

    private

    def handle_key(key)
      return :quit if key == TuiTui::KeyCode::CTRL_C
      return :quit if key == "q" && !capturing? # "q" is a normal character while a field captures keys

      case key
      when "\t" then refocus(@focus.next)
      when :backtab then refocus(focus_prev)
      else act(focused_field.handle(key))
      end
      self
    end

    def handle_mouse(event)
      return self unless event.action == :press

      hit = layout.find { |field, top| event.row.between?(top, top + field.rows - 1) }
      return self unless hit

      field, top = hit
      refocus(@focus.focus(field.key))
      act(field.click(event.row - top, event.col))
      self
    end

    # Interpret a field's reply: submit, or hand focus to a neighbour.
    def act(result)
      case result
      when :submit then submit
      when :focus_next then refocus(@focus.next)
      when :focus_prev then refocus(focus_prev)
      end
    end

    # Move focus, closing any open dropdown we are leaving (a click that keeps
    # focus on the same field is left alone, so it can act on its own list).
    def refocus(ring)
      if ring.current != @focus.current
        f = focused_field
        f.close if f.respond_to?(:close)
      end
      @focus = ring
    end

    def submit
      @errors = validate
      @done = @errors.empty? ? summarize : nil
      refocus(@focus.focus(first_invalid)) if first_invalid
    end

    def validate
      errors = {}
      errors[:name] = "required" if field(:name).value.strip.empty?
      email = field(:email).value.strip
      errors[:email] = "must look like a@b.c" unless email.match?(/\A[^@\s]+@[^@\s]+\.[^@\s]+\z/)
      errors
    end

    def summarize
      "Welcome, #{field(:name).value} <#{field(:email).value}> from #{field(:country).value} — " \
        "#{field(:role).value}; contact via #{field(:contact).summary}; bio #{field(:bio).summary}"
    end

    # ---- focus / layout helpers ----

    def focused_field = @fields.find { |f| @focus.focused?(f.key) }
    def field(key) = @fields.find { |f| f.key == key }
    def first_invalid = @errors.keys.first

    # Whether the focused field is consuming keys (a text field, or an open
    # dropdown) — so a bare "q" edits rather than quitting the app.
    def capturing? = focused_field.respond_to?(:capturing?) && focused_field.capturing?

    # Each field paired with its top row, stacked with a blank line between.
    def layout
      row = TOP
      @fields.map do |field|
        pair = [field, row]
        row += field.rows + 1
        pair
      end
    end

    # FocusRing only walks forward; step all the way round for Shift-Tab.
    def focus_prev
      ring = @focus
      (@fields.size - 1).times { ring = ring.next }
      ring
    end

    # ---- drawing ----

    def draw_field(canvas, field, top)
      focused = @focus.focused?(field.key)
      canvas.text(top, LABEL_COL - 2, ">", MARKER) if focused
      field.draw(canvas, top, focused: focused)
      err = @errors[field.key]
      canvas.text(top, VALUE_COL + VALUE_W + 2, "<- #{err}", ERR) if err
    end

    def draw_footer(canvas, size)
      _, last_top = layout.last
      row = last_top + 2
      if @done
        canvas.text(row, LABEL_COL, TuiTui::DisplayText.new(@done).truncate(size.cols - LABEL_COL), GOOD)
      elsif !@errors.empty?
        canvas.text(row, LABEL_COL, "Please fix the highlighted fields.", ERR)
      end
      hint = "Tab move  up/down within field  Space toggle  Enter submit (newline in Bio)  q quit"
      canvas.text(size.rows - 1, LABEL_COL, TuiTui::DisplayText.new(hint).truncate(size.cols - LABEL_COL), HINT)
    end
  end
end

if $PROGRAM_NAME == __FILE__
  TuiTui::Runtime.new(FormSample::Form.new).run
end
