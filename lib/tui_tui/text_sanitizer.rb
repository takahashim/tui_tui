# frozen_string_literal: true

module TuiTui
  # Normalizes text before rendering so malformed input bytes are displayed
  # safely instead of raising encoding errors.
  module TextSanitizer
    module_function

    def sanitize(string)
      string.valid_encoding? ? string : string.scrub("?")
    end
  end
end
