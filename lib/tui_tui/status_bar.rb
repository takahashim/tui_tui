# frozen_string_literal: true

require_relative "display_text"

module TuiTui
  # A one-row status/footer bar.
  # It draws left text from the start and optional right text flush right.
  module StatusBar
    module_function

    def draw(canvas, rect, left: "", right: nil, style: nil)
      canvas.fill(rect, style)

      right_width = right ? DisplayText.new(right).width : 0
      fits_right = right && right_width < rect.cols
      left_max = fits_right ? rect.cols - right_width : rect.cols

      canvas.text(rect.row, rect.col, DisplayText.new(left).truncate(left_max), style)
      canvas.text(rect.row, rect.col + rect.cols - right_width, right, style) if fits_right
      canvas
    end
  end
end
