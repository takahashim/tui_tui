# TuiTui

TuiTui is a small terminal UI toolkit for Ruby, with no external dependencies.

It uses a lightweight, TEA-inspired (MVU) architecture: the app object is the model,
`update(event)` returns the next app, and `view(size)` renders a `Canvas` that the runtime paints.

## Usage

An app is any object with two methods: `view(size)` returns a `Canvas`, and
`update(event)` returns the next app (or `:quit`). `Runtime#run` drives the loop.

```ruby
require "tui_tui"

class Counter
  def initialize(count = 0) = @count = count

  def view(size)
    TuiTui::Canvas.blank(size).text(1, 1, "count: #{@count}   (+/- to change, q to quit)")
  end

  def update(event)
    return self unless event.is_a?(TuiTui::KeyEvent)

    case event.key
    when "+", "=" then Counter.new(@count + 1)
    when "-", "_" then Counter.new(@count - 1)
    when "q", TuiTui::KeyCode::CTRL_C then :quit
    else self
    end
  end
end

TuiTui::Runtime.new(Counter.new).run
```

See [`examples/`](examples) for larger apps.
Each is runnable with `ruby examples/<name>.rb`.

- `examples/counter.rb` — the smallest possible app
- `examples/widgets.rb` — built-in modal widgets
- `examples/file_browser.rb` — two-pane file browser
- `examples/todo.rb` — todo list with prompts and filtering
- `examples/csv_viewer.rb` — fixed-header CSV table viewer

## Non-functional requirements

TuiTui is built around a small set of non-functional requirements (NFRs).

#### N1: Minimal dependencies.

Depends only on `io/console`, which is a default gem.

#### N2: Testable without a terminal.

State transitions (`update`) and drawing (`view`) are pure functions.
Only the driver (`Screen`) touches the terminal.

This makes apps and widgets unit-testable and snapshot-testable in headless environments.

#### N3: Terminal safety.

Raw mode, the alternate screen, and cursor visibility are always restored.
This applies to normal exits, exceptions, and signals.

This prevents the terminal from being left in a broken state.
The `Screen.run` block form guarantees this behavior through `TerminalSession`.

#### N4: No flicker.

Only the frame diff is written.
Each frame is flushed with a single `write`.

#### N5: Full-width aware.

Columns never misalign.
Display width is measured using a small built-in table based on East Asian Width.

Glyphs are clipped at region edges, not split across them.

#### N6: Performance.

Movement and redraw stay responsive, even with large content.
Only changed rows are repainted, so cost scales with the change, not the screen size.

#### N7: Width-safe UI chrome.

Self-drawn chrome defaults to ASCII, color, and spacing, which have a guaranteed
width of 1. Unicode box-drawing has an ambiguous width that can break layouts under
CJK terminal settings, so it is only used when the terminal is confirmed to render
it at width 1; otherwise the chrome falls back to ASCII.

Content text, such as Japanese data, is measured with `Width`.
It is clipped or padded to fit the available space.

## Configuration

Environment variables (all optional):

- `TUITUI_MOUSE` — set to `0`/`off`/`false` to disable mouse reporting (on by default).
- `TUITUI_BACKGROUND` — `light` or `dark` to pick the theme for your terminal background. Without it, `COLORFGBG` is read if present, otherwise `dark` is assumed (reliable auto-detection isn't possible on all terminals).
- `TUITUI_BOX` — `ascii` / `unicode` / `auto` to force or auto-detect Unicode box-drawing chrome (default `auto`: used only when the terminal renders it at width 1, else ASCII).

## Installation

```bash
bundle add tui_tui
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
gem install tui_tui
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests.
You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.
To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`,
which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/takahashim/tui_tui.
