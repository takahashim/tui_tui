# frozen_string_literal: true

require_relative "key_code"

module TuiTui
  # Shared navigation intent mapping for widgets.
  class KeyIntent
    NAVIGATION = {
      :up => :up,
      "k" => :up,
      :down => :down,
      "j" => :down,
      :home => :top,
      "g" => :top,
      :end => :bottom,
      "G" => :bottom
    }.freeze

    CANCEL = [:escape, "q", KeyCode::CTRL_C].freeze

    def self.for(key) = new.for(key)

    def for(key)
      return :cancel if CANCEL.include?(key)

      NAVIGATION[key]
    end
  end
end
