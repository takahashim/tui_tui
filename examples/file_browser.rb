#!/usr/bin/env ruby
# frozen_string_literal: true

# A sample TUI built on TuiTui ALONE — it never touches the trace viewer.
# Its point is to show the framework is domain-agnostic: a two-pane app (a
# directory list + a file preview) in ~150 lines, reusing Canvas, Style, Width
# (so Japanese file names align), Screen, Runtime, and Keys.
#
#   ruby examples/file_browser.rb [DIR]
#
# Keys: j/k (or ↑/↓) move, l/Enter/→ open dir, h/←/Backspace up, g/G top/bottom,
# Tab switch pane, J/K (or mouse wheel) scroll the preview, w wrap, t theme, </> divider, / fuzzy find,
# y copy the path (OSC 52), m actions menu, ? help, q (or Ctrl-C) quit.
#
# `/` is an incremental fuzzy finder built on TuiTui::Fuzzy (type to narrow,
# matched characters highlighted, ↑↓ to navigate, Enter to open, Esc to cancel).
# The m / ? / q modals are TuiTui widgets (Select, Help, Confirm).

require "strscan"
require_relative "../lib/tui_tui"

module FileBrowserSample
  S = TuiTui::Style
  # The chrome palette is derived from a TuiTui::Theme, so changing the theme
  # (the "t" key cycles the hues) recolours both this app and the modals it opens.
  # Every hue follows the detected terminal background (light/dark) via Theme.auto.
  THEMES = %i[cool warm mono].freeze

  def self.theme_for(hue) = TuiTui::Theme.auto(hue: hue)

  def self.palette(theme)
    {
      # Directories: the theme's structural-emphasis role (so they follow the
      # theme and stay distinct from fuzzy matches, which use :accent).
      dir: theme.title,
      file: theme.text,
      dim: theme.muted,                              # subdued text (preview, hints)
      divider: theme.frame,                          # the rule between panes
      select: theme.selection,                       # focused selection
      select_blur: theme.selection_dim,              # unfocused selection (theme role)
      bar: theme.bar,                                # footer bar (theme role)
      match: theme.accent,                           # fuzzy-matched characters
    }
  end

  # Token colours for the preview's tiny highlighter. Syntax colours are kept
  # independent of the (switchable) UI theme — like an editor's fixed code theme.
  BASE = TuiTui::Theme::DEFAULT
  CODE = {
    text: BASE.text,
    comment: BASE.muted,         # grey
    string: S.new(fg: 108),      # sage
    number: S.new(fg: 173),      # dusty orange
    keyword: S.new(fg: 109),     # slate
    symbol: S.new(fg: 139),      # mauve
    constant: S.new(fg: 144),    # khaki
    heading: BASE.title,         # markdown heading (slate bold)
    bold: S.new(attrs: [:bold]), # markdown **bold**
    italic: S.new(attrs: [:italic]), # markdown *italic*
    link: BASE.accent,           # markdown [text](url)
  }.freeze

  # A minimal, dependency-free syntax highlighter for the preview. It is
  # line-based (regex per token), so multi-line strings/heredocs may mis-colour
  # — enough to make code readable, not a real parser. Ruby gets keywords/
  # symbols/constants; other source files get strings/numbers/line-comments.
  module Code
    KEYWORDS = %w[
      def end if elsif else unless while until for in do begin rescue ensure retry
      class module self nil true false and or not return yield then case when
      require require_relative attr_reader attr_accessor attr_writer
      raise next break super lambda proc new
    ].freeze
    KEYWORD = /(?:#{KEYWORDS.join("|")})\b/.freeze

    RUBY = [
      [/#.*/, :comment],
      [/"(?:\\.|[^"\\])*"/, :string],
      [/'(?:\\.|[^'\\])*'/, :string],
      [/::/, :text], # namespace separator, so "Foo::Bar" isn't read as a :symbol
      [/:[A-Za-z_]\w*[?!]?/, :symbol],
      [/\d[\d_]*(?:\.\d+)?/, :number],
      [KEYWORD, :keyword],
      [/[A-Z]\w*/, :constant],
      [/[a-z_]\w*[?!]?/, :text], # whole identifiers, so keywords inside words don't split
    ].freeze

    GENERIC = [
      [%r{//.*}, :comment],
      [/#.*/, :comment],
      [/"(?:\\.|[^"\\])*"/, :string],
      [/'(?:\\.|[^'\\])*'/, :string],
      [/\d[\d_]*(?:\.\d+)?/, :number],
    ].freeze

    # Line-based Markdown: whole-line constructs (heading/quote/hr/list marker)
    # via ^-anchored rules, then inline code/bold/italic/links. Underscore
    # emphasis is intentionally unsupported (it false-matches words like a_b).
    MARKDOWN = [
      [/^\s{0,3}#+\s.*/, :heading],                 # # Heading (whole line)
      [/^\s*(?:-{3,}|\*{3,})\s*$/, :comment],       # --- horizontal rule
      [/^\s{0,3}>.*/, :comment],                    # > blockquote
      [/^\s*(?:[-*+]|\d+\.)\s/, :symbol],           # list marker (then inline rules continue)
      [/`[^`]*`/, :string],                         # `inline code`
      [/\*\*[^*]+\*\*/, :bold],                     # **bold**
      [/\*[^*]+\*/, :italic],                       # *italic*
      [/\[[^\]]*\]\([^)]*\)/, :link],               # [text](url)
    ].freeze

    EXT = {
      ".rb" => :ruby, ".rake" => :ruby, ".gemspec" => :ruby, ".ru" => :ruby,
      ".js" => :generic, ".ts" => :generic, ".py" => :generic, ".c" => :generic,
      ".h" => :generic, ".cpp" => :generic, ".go" => :generic, ".rs" => :generic,
      ".java" => :generic, ".sh" => :generic, ".json" => :generic,
      ".yml" => :generic, ".yaml" => :generic, ".css" => :generic, ".scss" => :generic,
      ".md" => :markdown, ".markdown" => :markdown,
    }.freeze

    RULESETS = { ruby: RUBY, markdown: MARKDOWN }.freeze

    module_function

    def lang_for(ext) = EXT[ext.to_s.downcase]

    def rules(lang) = RULESETS.fetch(lang, GENERIC)

    # Tokenise one line into a styled Line.
    def line(text, lang)
      scanner = StringScanner.new(text)
      spans = []
      pending = +""
      until scanner.eos?
        role, token = first_match(scanner, rules(lang))
        if token
          flush(spans, pending)
          pending = +""
          spans << TuiTui::Span[token, CODE[role]]
        else
          pending << scanner.getch
        end
      end
      flush(spans, pending)
      TuiTui::Line.new(spans.empty? ? [TuiTui::Span[text, CODE[:text]]] : spans)
    end

    def first_match(scanner, ruleset)
      ruleset.each do |regex, role|
        token = scanner.scan(regex)
        return [role, token] if token
      end
      [nil, nil]
    end

    def flush(spans, pending)
      spans << TuiTui::Span[pending, CODE[:text]] unless pending.empty?
    end
  end

  MIN_TWO_PANE = 60
  MIN_PANE = 12       # smallest either pane may shrink to when dragging the divider
  SPLIT_STEP = 0.04   # how far </> nudge the divider per press
  WHEEL_STEP = 3      # rows scrolled per mouse-wheel notch
  DOUBLE_CLICK = 0.4  # seconds; a second click on the same entry within this opens it
  PREVIEW_BYTES = 64 * 1024
  PREVIEW_LINES = 1000

  HELP = [
    ["j / k  ↑ / ↓", "move"],
    ["Space / b", "page down / up"],
    ["g / G", "top / bottom"],
    ["l  Enter  →", "open directory"],
    ["h  ←  Backspace", "up to parent"],
    ["< / >", "move the divider"],
    ["Tab", "focus list / preview (j k g G page-keys follow focus)"],
    ["J / K", "scroll preview (from either pane)"],
    ["w", "toggle preview wrap"],
    ["t", "cycle theme (cool / warm / mono, follows light/dark)"],
    ["/", "fuzzy find (↑↓ navigate, Enter open, Esc cancel)"],
    ["y", "copy path to clipboard"],
    ["m", "actions menu"],
    ["?", "this help"],
    ["q", "quit"],
  ].freeze

  ACTIONS = [["Up to parent", :parent], ["Refresh", :refresh], ["Quit", :quit]].freeze

  # The app: responds to view(size) -> Canvas and update(event) -> self | :quit,
  # which is all TuiTui::Runtime asks of it.
  class Browser
    def initialize(path)
      @dir = File.expand_path(path)
      @list = TuiTui::ScrollList.new
      @preview_scroll = 0
      @preview_wrap = false # toggle with "w": wrap long lines vs. clip them
      @hl_path = nil        # cache key for syntax-highlighted preview lines
      @list_rect = nil      # last list pane rect, for click hit-testing
      @last_click = nil     # [index, time] of the last list click, for double-click
      @toast = nil          # transient notification (e.g. after copying a path)
      @preview_rect = nil   # last preview pane rect, for wheel hit-testing
      @theme_i = 0          # index into THEMES; "t" cycles
      @theme = FileBrowserSample.theme_for(THEMES[@theme_i])
      @styles = FileBrowserSample.palette(@theme)
      @focus = TuiTui::FocusRing.new(:list, :preview)
      @page = 1
      @preview_page = 1
      @split = 0.5 # divider position as a fraction of the body width (resize-safe)
      @finder = nil # the fuzzy query while finding (a String), or nil when off
      @matches = {} # entry name => matched char positions, for highlighting
      @modal = nil
      @on_result = nil
      @clipboard = nil # a path queued for the clipboard; the Runtime drains it
      load_entries
    end

    # The Runtime calls this after `update` and copies the returned text (OSC 52),
    # then clears it. Keeping the I/O out of `update` leaves the fold pure.
    def take_clipboard
      text = @clipboard
      @clipboard = nil
      text
    end

    # Keep ticking only while a toast is showing, so it auto-dismisses.
    def wants_tick? = !@toast.nil?

    def update(event)
      @toast = nil if @toast&.expired?
      case event
      when TuiTui::MouseEvent then @modal ? route_modal_mouse(event) : handle_mouse(event)
      when TuiTui::KeyEvent
        return route_modal(event.key) if @modal
        return finder_key(event.key) if @finder

        handle_key(event.key)
      else self
      end
    end

    # Wheel scrolls whichever pane the pointer is over (the list moves its cursor;
    # the preview scrolls its text). A click/drag in the list selects that entry.
    def handle_mouse(event)
      case event.action
      when :wheel
        delta = event.button == :wheel_up ? -WHEEL_STEP : WHEEL_STEP
        in_preview?(event.col) ? scroll_preview(delta) : move(delta)
      when :press then click_list(event)
      when :drag then drag_select(event)
      end
      self
    end

    def in_preview?(col) = @preview_rect && col >= @preview_rect.col

    # A click selects the entry under the pointer; a second click on the same
    # entry within DOUBLE_CLICK seconds opens it (a directory enters it).
    def click_list(event)
      index = entry_at(event) or return

      go_to(index)
      if double_click?(index)
        @last_click = nil # avoid a triple-click re-opening
        open_entry
      else
        @last_click = [index, monotonic]
      end
    end

    # Drag scrubs the selection (no double-click semantics).
    def drag_select(event)
      index = entry_at(event)
      go_to(index) if index
    end

    # The list index under the pointer, or nil (preview pane, out of bounds, or
    # below the last entry). Index 0 is valid, so use an explicit nil check.
    def entry_at(event)
      rect = @list_rect
      return nil if in_preview?(event.col) || rect.nil?
      return nil unless event.row.between?(rect.row, rect.row + rect.rows - 1)

      index = @list.top + (event.row - rect.row)
      index unless index > @list.last
    end

    def double_click?(index)
      @last_click && @last_click[0] == index && (monotonic - @last_click[1]) <= DOUBLE_CLICK
    end

    def monotonic = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    def view(ctx)
      size = ctx.size
      canvas = ctx.canvas
      body, status = split_status(size)
      list_rect, preview_rect = split_panes(body)
      @list_rect = list_rect       # remembered so a click can hit-test the list
      @preview_rect = preview_rect # and tell which pane the pointer is in

      @page = [list_rect.rows, 1].max
      @preview_page = [preview_rect&.rows || 1, 1].max # for paging the preview when it is focused
      @list.ensure_visible(list_rect.rows)

      draw_list(canvas, list_rect)
      draw_divider(canvas, list_rect) if preview_rect
      draw_preview(canvas, preview_rect) if preview_rect
      draw_status(canvas, status) if status
      @toast&.draw(canvas, size, style: @theme.selection)
      @modal&.draw(canvas, size) # modal overlay on top of everything
      canvas
    end

    private

    # --- modals ---

    # Show a modal widget; `on_result` interprets its resolved value (and may
    # return :quit). A widget returns nil from `handle` while still open.
    def open_modal(widget, &on_result)
      @modal = widget
      @on_result = on_result
    end

    def route_modal(key) = resolve_modal(@modal.handle(key))
    def route_modal_mouse(event) = resolve_modal(@modal.handle_mouse(event))

    def resolve_modal(result)
      return self if result.nil? # still open

      @modal = nil
      @on_result.call(result) == :quit ? :quit : self
    end

    def confirm_quit
      open_modal(TuiTui::Confirm.new("Quit file browser?", theme: @theme)) { |r| :quit if r == :ok }
    end

    def open_actions
      open_modal(TuiTui::Select.new("Actions", ACTIONS.map(&:first), theme: @theme)) do |result|
        run_action(result) if result.is_a?(Integer)
      end
    end

    def run_action(index)
      case ACTIONS[index][1]
      when :parent then up_dir
      when :refresh then load_entries
      when :quit then :quit
      end
    end

    # --- input ---

    def handle_key(key)
      case key
      when "q", TuiTui::KeyCode::CTRL_C then confirm_quit
      when "?" then open_modal(TuiTui::Help.new("Keys", HELP, theme: @theme)) { nil }
      when "/" then enter_finder
      when "m" then open_actions
      when "l", "\r", :right then open_entry
      when "h", :left, TuiTui::KeyCode::BACKSPACE then up_dir # h / ← / Backspace
      when "\t" then @focus = @focus.next
      when "<" then @split = [@split - SPLIT_STEP, 0.1].max
      when ">" then @split = [@split + SPLIT_STEP, 0.9].min
      when "J" then scroll_preview(1) # always works, whichever pane is focused
      when "K" then scroll_preview(-1)
      when "w" then toggle_preview_wrap
      when "t" then cycle_theme
      when "y" then copy_path
      else navigate(key) # j/k, arrows, paging and g/G follow the focused pane
      end
      self
    end

    # Cycle the UI theme (default -> warm -> mono -> ...), rebuilding the chrome
    # palette. Open modals read @theme when created, so the next one matches too.
    # Queue the selected path for the clipboard (drained by the Runtime) and show
    # a toast so the copy is visibly confirmed.
    def copy_path
      @clipboard = File.expand_path(File.join(@dir, selected.to_s))
      @toast = TuiTui::Toast.new("copied path to clipboard")
    end

    def cycle_theme
      @theme_i = (@theme_i + 1) % THEMES.size
      @theme = FileBrowserSample.theme_for(THEMES[@theme_i])
      @styles = FileBrowserSample.palette(@theme)
    end

    # Move/page keys act on whichever pane Tab has focused: the directory list,
    # or the file preview (scrolling its text back and forth).
    def navigate(key)
      @focus.focused?(:preview) ? navigate_preview(key) : navigate_list(key)
    end

    def navigate_list(key)
      case key
      when "j", :down then move(1)
      when "k", :up then move(-1)
      when " ", :pgdn then move(@page)
      when "b", :pgup then move(-@page)
      when "g", :home then go_to(0)
      when "G", :end then go_to(@list.last)
      end
    end

    def navigate_preview(key)
      case key
      when "j", :down then scroll_preview(1)
      when "k", :up then scroll_preview(-1)
      when " ", :pgdn then scroll_preview(@preview_page)
      when "b", :pgup then scroll_preview(-@preview_page)
      when "g", :home then @preview_scroll = 0
      when "G", :end then @preview_scroll = 1 << 30 # draw clamps to the last line
      end
    end

    def scroll_preview(delta)
      @preview_scroll = [@preview_scroll + delta, 0].max # upper bound clamped in draw_preview
    end

    def toggle_preview_wrap
      @preview_wrap = !@preview_wrap
      @preview_scroll = 0 # the display-line count changes, so start from the top
    end

    def move(delta)
      @list.move(delta)
      @preview_scroll = 0
    end

    def go_to(index)
      @list.go_to(index)
      @preview_scroll = 0
    end

    def open_entry
      name = selected
      return up_dir if name == ".."
      return unless directory?(name)

      @dir = File.join(@dir, name)
      load_entries
      go_to(0)
    end

    def up_dir
      parent = File.dirname(@dir)
      return if parent == @dir # already at the filesystem root

      came_from = File.basename(@dir)
      @dir = parent
      load_entries
      go_to(@entries.index(came_from) || 0)
    end

    def selected = @entries[@list.cursor]

    # --- fuzzy finder (incremental; built on TuiTui::Fuzzy) ---

    def enter_finder
      @finder = ""
      refilter
    end

    def exit_finder
      @finder = nil
      refilter
    end

    # While finding: arrows navigate, printable keys narrow the query, Enter opens
    # the top/selected match, Esc cancels. Letters type into the query (not move),
    # so navigation is the arrow keys.
    def finder_key(key)
      case key
      when :escape, TuiTui::KeyCode::CTRL_C then exit_finder
      when "\r" then choose_finding
      when :up then move(-1)
      when :down then move(1)
      when TuiTui::KeyCode::BACKSPACE, :backspace then backspace_finder
      when String then type_finder(key)
      end
      self
    end

    def type_finder(key)
      return unless key.bytes.all? { |b| b >= 0x20 && b != 0x7F } # printable only

      @finder += key
      refilter
    end

    def backspace_finder
      return if @finder.empty?

      @finder = @finder[0...-1]
      refilter
    end

    # Open the highlighted match (and leave finder mode).
    def choose_finding
      target = selected
      exit_finder
      go_to(@entries.index(target) || 0)
      open_entry
    end

    # --- directory model ---

    # Directories first, then files, each alphabetical; ".." unless at the root.
    # `@all` is the full list; `@entries` is what's shown (fuzzy-ranked when finding).
    def load_entries
      names = (Dir.children(@dir) rescue []).sort_by do |name|
        [directory?(name) ? 0 : 1, name.downcase]
      end
      @all = (@dir == File.dirname(@dir) ? [] : [".."]) + names
      @cache_path = nil
      refilter
    end

    # Recompute the visible entries: fuzzy-ranked while finding (best match first,
    # with matched positions for highlighting), otherwise the full dir-first list.
    def refilter
      if @finder && !@finder.empty?
        ranked = TuiTui::Fuzzy.new(@finder).rank(@all)
        @entries = ranked.map(&:first)
        @matches = ranked.to_h { |name, found| [name, found.positions] }
      else
        @entries = @all
        @matches = {}
      end
      @list.count = @entries.size
      go_to(0)
    end

    def directory?(name) = File.directory?(File.join(@dir, name))

    # --- layout ---

    def split_status(size)
      return [whole(size), nil] if size.rows < 2

      whole(size).split_h(size.rows - 1)
    end

    def split_panes(body)
      return [body, nil] if body.cols < MIN_TWO_PANE

      body.split_ratio(@split, min: MIN_PANE, gutter: 1)
    end

    def whole(size) = TuiTui::Rect.new(row: 1, col: 1, rows: size.rows, cols: size.cols)

    # --- drawing ---

    # A dim vertical rule in the 1-column gutter between the panes (the column
    # split_ratio left between list and preview). Follows the canvas chrome:
    # ASCII "|" by default, "│" when the terminal probed as Unicode-capable.
    def draw_divider(canvas, list_rect)
      col = list_rect.col + list_rect.cols
      canvas.fill(TuiTui::Rect.new(row: list_rect.row, col: col, rows: list_rect.rows, cols: 1), @styles[:divider], canvas.chrome.v)
    end

    def draw_list(canvas, rect)
      highlight = @focus.focused?(:list) ? @styles[:select] : @styles[:select_blur]
      TuiTui::List.new(@list).draw(canvas, rect, highlight: highlight, scrollbar: @theme) do |index, selected|
        name = @entries[index]
        label = directory?(name) && name != ".." ? "#{name}/" : name
        base = selected ? highlight : (directory?(name) ? @styles[:dir] : @styles[:file])
        entry_line(label, name, base) # List reserves the gutter, truncates, and draws the scrollbar
      end
    end

    # The label as a Line: fuzzy-matched characters get the match style, the rest
    # the base style. Adjacent same-style characters coalesce into one span.
    def entry_line(label, name, base)
      positions = @finder ? @matches[name] : nil
      return TuiTui::Line[TuiTui::Span[label, base]] unless positions

      spans = []
      run = +""
      run_style = nil
      label.grapheme_clusters.each_with_index do |grapheme, i| # grapheme indices to match Fuzzy#positions
        style = positions.include?(i) ? @styles[:match] : base
        spans << TuiTui::Span[run, run_style] if style != run_style && !run.empty?
        run = +"" if style != run_style
        run_style = style
        run << grapheme
      end
      spans << TuiTui::Span[run, run_style] unless run.empty?
      TuiTui::Line.new(spans)
    end

    def draw_preview(canvas, rect)
      width = rect.split_gutter.first.cols # leave room for the scrollbar gutter when wrapping/truncating
      lines = preview_display(width)
      @preview_scroll = @preview_scroll.clamp(0, [lines.length - 1, 0].max)
      TuiTui::TextView.draw(canvas, rect, lines, top: @preview_scroll, scrollbar: @theme)
    end

    # Preview as styled display lines (Line). Wrap mode wraps to the width (plain,
    # since wrapping styled spans is out of scope); a code file is syntax-
    # highlighted; anything else is plain subdued text.
    def preview_display(width)
      if @preview_wrap
        preview_lines.flat_map { |line| TuiTui::DisplayText.new(line).wrap(width) }
                     .map { |dt| plain_line(dt.to_s) }
      elsif (lang = preview_lang)
        highlighted(lang)
      else
        preview_lines.map { |line| plain_line(line) }
      end
    end

    def plain_line(text) = TuiTui::Line[TuiTui::Span[text, @styles[:dim]]]

    # The highlighter language for the selected file, or nil (no highlighting).
    def preview_lang
      return nil unless selected && selected != ".." && !directory?(selected)

      Code.lang_for(File.extname(selected.to_s))
    end

    # Syntax-highlighted preview Lines, cached per selection (like preview_lines).
    def highlighted(lang)
      path = File.join(@dir, selected.to_s)
      return @hl_lines if @hl_path == path

      @hl_path = path
      @hl_lines = preview_lines.map { |line| Code.line(line, lang) }
    end

    def draw_status(canvas, rect)
      left = @finder ? " > #{@finder}" : " #{@dir}"
      hints = @finder ? "Esc=cancel  Enter=open" : "?=help  /=find  m=menu  t=#{THEMES[@theme_i]}  q=quit"
      right = "#{@list.cursor + 1}/#{@entries.size}  #{hints} "
      TuiTui::StatusBar.draw(canvas, rect, left: left, right: right, style: @styles[:bar])
    end

    # Lines of the selected file's preview, cached per selection so we do not
    # re-read the file on every idle tick.
    def preview_lines
      path = File.join(@dir, selected.to_s)
      return @cache_lines if @cache_path == path

      @cache_path = path
      @cache_lines = build_preview(path)
    end

    def build_preview(path)
      name = selected
      return ["(parent directory)"] if name == ".."
      return ["(directory)"] if directory?(name)

      data = File.binread(path, PREVIEW_BYTES)
      return ["(empty file)"] if data.nil? || data.empty?
      return ["(binary file)"] if data.include?("\u0000")

      data.force_encoding("UTF-8").lines.first(PREVIEW_LINES).map { |line| line.chomp.gsub("\t", "    ") }
    rescue SystemCallError
      ["(unreadable)"]
    end
  end
end

if $PROGRAM_NAME == __FILE__
  TuiTui::Runtime.new(FileBrowserSample::Browser.new(ARGV[0] || ".")).run
end
