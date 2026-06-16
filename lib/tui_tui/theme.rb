# frozen_string_literal: true

require_relative "style"

module TuiTui
  # Semantic Style roles shared by the built-in widgets.
  # Themes combine a background surface with an accent hue.
  Theme = Data.define(
    # box borders / dividers
    :frame,
    :title,
    :text,
    # de-emphasized text (descriptions, body)
    :muted,
    # highlighted detail (e.g. key names)
    :accent,
    # the focused/selected item or button
    :selection,
    # a selected item in an unfocused pane (de-emphasized)
    :selection_dim,
    # status / footer bar background
    :bar,
    :cursor,
    :scroll_track,
    :scroll_thumb
  )

  class Theme
    # Background-dependent neutral roles.
    SURFACES = {
      dark: {
        text: Style.new,
        muted: Style.new(fg: 245),
        bar: Style.new(fg: 252, bg: 238),
        selection_dim: Style.new(fg: 247, bg: 238)
      },
      light: {
        text: Style.new,
        muted: Style.new(fg: 240),
        bar: Style.new(fg: 16, bg: 252),
        selection_dim: Style.new(fg: 240, bg: 252)
      }
    }.freeze

    # Accent roles per hue and background.
    ACCENTS = {
      cool: {
        dark: {line: 66, title: 109, accent: 73, sel: [231, 60]},
        light: {line: 30, title: 25, accent: 30, sel: [16, 152]}
      },
      warm: {
        dark: {line: 95, title: 137, accent: 173, sel: [231, 95]},
        light: {line: 95, title: 94, accent: 130, sel: [16, 180]}
      },
      mono: {
        dark: {line: 240, title: 252, accent: 252, sel: [16, 250]},
        light: {line: 240, title: 236, accent: 236, sel: [16, 250]}
      }
    }.freeze

    # COLORFGBG background values meaning "light".
    LIGHT_FGBG = %w[7 15].freeze

    def self.bold(fg) = Style.new(fg: fg, attrs: [:bold])

    # Build the palette for a (background, hue) pair.
    def self.compose(background, hue)
      surface = SURFACES.fetch(background)
      a = ACCENTS.fetch(hue).fetch(background)
      selection = Style.new(fg: a[:sel][0], bg: a[:sel][1])
      new(
        frame: Style.new(fg: a[:line]),
        title: bold(a[:title]),
        text: surface[:text],
        muted: surface[:muted],
        accent: bold(a[:accent]),
        selection: selection,
        selection_dim: surface[:selection_dim],
        bar: surface[:bar],
        cursor: selection,
        scroll_track: Style.new(fg: a[:line]),
        scroll_thumb: Style.new(bg: a[:sel][1])
      )
    end

    # Shared palettes for every surface/hue pair.
    TABLE = SURFACES.keys.product(ACCENTS.keys).to_h { |bg, hue| [[bg, hue], compose(bg, hue)] }.freeze

    def self.build(background: :dark, hue: :cool) = TABLE.fetch([background, hue])

    # Best-effort terminal background (:light/:dark).
    def self.detect_background(env: ENV)
      case env["TUITUI_BACKGROUND"]&.downcase
      when "light"
        :light
      when "dark"
        :dark
      else
        bg = env["COLORFGBG"]&.split(";")&.last
        bg && LIGHT_FGBG.include?(bg) ? :light : :dark
      end
    end

    # The hue palette tuned for the detected background.
    def self.auto(hue: :cool, env: ENV) = build(background: detect_background(env: env), hue: hue)

    # Fetch a preset by name (Symbol/String); unknown names fall back to DEFAULT.
    def self.named(name) = PRESETS.fetch(name&.to_sym, DEFAULT)
  end

  Theme::DARK = Theme.build(background: :dark, hue: :cool)
  Theme::LIGHT = Theme.build(background: :light, hue: :cool)
  Theme::DEFAULT = Theme::DARK
  Theme::WARM = Theme.build(background: :dark, hue: :warm)
  Theme::MONO = Theme.build(background: :dark, hue: :mono)

  class Theme
    PRESETS = {
      default: DEFAULT,
      cool: DEFAULT,
      dark: DARK,
      light: LIGHT,
      warm: WARM,
      mono: MONO
    }.freeze
  end
end
