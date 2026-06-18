# frozen_string_literal: true

module TuiTui
  # Character-level text hygiene: keeps malformed or control bytes out of the
  # render/input pipeline so they are displayed safely (or rejected as input)
  # instead of raising encoding errors or emitting raw control codes.
  module TextSanitizer
    module_function

    def sanitize(string)
      string.valid_encoding? ? string : string.scrub("?")
    end

    # Whether `string` is safe to insert as literal text: every byte is a
    # printable character (no C0 controls and no DEL). Multibyte UTF-8 passes,
    # since its bytes are all >= 0x80.
    def printable?(string)
      string.bytes.all? { |byte| byte >= 0x20 && byte != 0x7F }
    end
  end
end
