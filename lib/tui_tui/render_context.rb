# frozen_string_literal: true

require_relative "canvas"

module TuiTui
  # What an app's `view` receives: the terminal size plus the resolved chrome
  RenderContext = Data.define(:size, :chrome) do
    def rows = size.rows
    def cols = size.cols

    # A blank canvas already carrying the resolved chrome.
    def canvas = Canvas.blank(size, chrome: chrome)
  end
end
