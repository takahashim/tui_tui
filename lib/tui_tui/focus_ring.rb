# frozen_string_literal: true

module TuiTui
  # Immutable focus state for a fixed set of targets.
  class FocusRing
    attr_reader :current

    def initialize(*targets, current: nil)
      @targets = targets.flatten.freeze
      raise ArgumentError, "FocusRing needs at least one target" if @targets.empty?

      @current = current || @targets.first
    end

    def focused?(target) = @current == target

    def next
      focus(@targets[(@targets.index(@current) + 1) % @targets.size])
    end

    def focus(target)
      @targets.include?(target) ? self.class.new(@targets, current: target) : self
    end
  end
end
