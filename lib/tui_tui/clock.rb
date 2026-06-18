# frozen_string_literal: true

module TuiTui
  # The single source of monotonic time, so timers and timeouts never depend on
  # wall-clock adjustments. Injected as a callable where tests need to control it.
  module Clock
    module_function

    def monotonic = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
