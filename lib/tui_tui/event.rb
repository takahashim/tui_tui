# frozen_string_literal: true

module TuiTui
  # Runtime event values.
  KeyEvent = Data.define(:key)
  ResizeEvent = Data.define(:size)
  TickEvent = Data.define
  MouseEvent = Data.define(:action, :button, :col, :row)
  EofEvent = Data.define
end
