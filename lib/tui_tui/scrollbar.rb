# frozen_string_literal: true

require_relative "rect"
require_relative "style"
require_relative "theme"

module TuiTui
  # A vertical scroll indicator for a 1-column gutter.
  # It sizes a thumb from top/visible/total and draws ASCII-only chrome.
  module Scrollbar
    module_function

    TRACK = Theme::DEFAULT.scroll_track
    THUMB = Theme::DEFAULT.scroll_thumb

    def draw(canvas, rect, top:, visible:, total:, track: nil, thumb: " ", track_style: TRACK, thumb_style: THUMB)
      return canvas if rect.rows <= 0

      track ||= canvas.chrome.track
      length, offset = geometry(rect.rows, top, visible, total)
      rect.rows.times do |i|
        in_thumb = i >= offset && i < offset + length
        canvas.text(rect.row + i, rect.col, in_thumb ? thumb : track, in_thumb ? thumb_style : track_style)
      end

      canvas
    end

    # The thumb's [length, offset] in rows for a `height`-row track. Returns
    # [0, 0] (no thumb, track only) when everything fits — nothing to scroll.
    def geometry(height, top, visible, total)
      visible = [visible, 1].max
      total = [total, visible].max
      return [0, 0] if total <= visible

      length = [(height * visible / total.to_f).round, 1].max.clamp(1, height)
      offset = ((height - length) * top.to_f / (total - visible)).round
      [length, offset.clamp(0, height - length)]
    end
  end
end
