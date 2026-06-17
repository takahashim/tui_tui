# frozen_string_literal: true

require_relative "canvas"

module TuiTui
  # What an app's `view` receives: the terminal size
  RenderContext = Data.define(:size) do
    def rows = size.rows
    def cols = size.cols

    def canvas = Canvas.blank(size)
  end
end
