#!/usr/bin/env ruby
# frozen_string_literal: true

# A gallery of the built-in TuiTui widgets (Confirm / Select / Prompt / Help)
# driven as modal overlays. The host keeps one modal while open, routes keys to
# its `handle`, draws it over its own frame, and interprets the resolved value —
# the same pattern any TuiTui app uses. The main screen shows the last result.
# Press `t` to cycle the theme; the gallery text and the next modal follow it.
#
#   ruby examples/widgets.rb
#
# Keys: c confirm, s select, p prompt, ? help, t theme, q (or Ctrl-C) quit.

require_relative "../lib/tui_tui"

module WidgetsSample
  THEMES = %i[cool warm mono].freeze

  ITEMS = ["Red", "Green", "Blue", "日本語の項目", "Yellow"].freeze
  HELP = [
    ["c", "open a confirm dialog"],
    ["s", "open a select list"],
    ["p", "open a text prompt"],
    ["t", "cycle theme (cool / warm / mono, follows light/dark)"],
    ["?", "this help"],
    ["q", "quit"],
  ].freeze

  class Gallery
    def initialize
      @last = "(nothing yet)"
      @modal = nil
      @on_result = nil
      @theme_i = 0
      @theme = TuiTui::Theme.auto(hue: THEMES[@theme_i])
    end

    def update(event)
      case event
      when TuiTui::MouseEvent then @modal ? route_modal_mouse(event) : self
      when TuiTui::KeyEvent
        return route_modal(event.key) if @modal

        handle_key(event.key)
      else self
      end
    end

    def view(ctx)
      size = ctx.size
      canvas = ctx.canvas
      canvas.text(2, 3, "TuiTui widget gallery", @theme.title)
      canvas.text(4, 3, "theme: #{THEMES[@theme_i]}", @theme.accent)
      canvas.text(5, 3, "last result: #{@last}", @theme.text)
      canvas.text(7, 3, "c confirm   s select   p prompt   ? help   t theme   q quit", @theme.muted)
      @modal&.draw(canvas, size) # modal overlays the main screen
      canvas
    end

    private

    def handle_key(key)
      case key
      when "q", TuiTui::KeyCode::CTRL_C then return :quit
      when "c" then open(TuiTui::Confirm.new("Proceed?", theme: @theme)) { |r| @last = "confirm -> #{r}" }
      when "s" then open(TuiTui::Select.new("Pick a color", ITEMS, theme: @theme)) { |r| @last = "select -> #{label(r)}" }
      when "p" then open(TuiTui::Prompt.new("Name:", theme: @theme)) { |r| @last = "prompt -> #{prompt_value(r)}" }
      when "?" then open(TuiTui::Help.new("Keys", HELP, theme: @theme)) { nil }
      when "t" then cycle_theme
      end
      self
    end

    def cycle_theme
      @theme_i = (@theme_i + 1) % THEMES.size
      @theme = TuiTui::Theme.auto(hue: THEMES[@theme_i])
    end

    def open(widget, &on_result)
      @modal = widget
      @on_result = on_result
    end

    def route_modal(key) = resolve_modal(@modal.handle(key))
    def route_modal_mouse(event) = resolve_modal(@modal.handle_mouse(event))

    def resolve_modal(result)
      return self if result.nil? # still open

      @modal = nil
      @on_result.call(result)
      self
    end

    def label(result) = result.is_a?(Integer) ? ITEMS[result] : result
    def prompt_value(result) = result.is_a?(Array) ? result[1].inspect : result
  end
end

if $PROGRAM_NAME == __FILE__
  TuiTui::Runtime.new(WidgetsSample::Gallery.new).run
end
