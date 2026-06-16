# frozen_string_literal: true

module TuiTui
  # Resolves the color depth the renderer may safely emit.
  module ColorDepth
    TRUECOLOR = %w[truecolor 24bit].freeze
    MODES = %i[none basic16 ansi256 truecolor].freeze

    def self.detect(env = ENV)
      return :none if disabled?(env)
      return :truecolor if TRUECOLOR.include?(env["COLORTERM"])

      :ansi256
    end

    def self.from(name, env = ENV)
      # Unknown overrides fall back to auto-detection instead of failing startup.
      case name.to_s.downcase
      when "none", "no", "off", "0"
        :none
      when "16", "basic", "basic16", "ansi16"
        :basic16
      when "256", "ansi256"
        :ansi256
      when "truecolor", "24bit", "full"
        :truecolor
      else
        detect(env)
      end
    end

    def self.disabled?(env)
      return true if env.key?("NO_COLOR")

      term = env["TERM"]
      term.nil? || term.empty? || term == "dumb"
    end
  end
end
