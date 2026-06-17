# frozen_string_literal: true

require "spec_helper"

module TuiTui
  # The loop is normally tty-bound; here Screen.run is stubbed to yield a fake
  # screen with a scripted event stream, so the fold/render/quit wiring is
  # exercised headless (this is what catches arity / dispatch regressions in the
  # helpers the loop calls).
  RSpec.describe Runtime do
    Events = Struct.new(:queue) do
      def next_event(tick:) = queue.shift || EofEvent.new
    end

    # Records renders / invalidations / clipboard writes; serves scripted events.
    class FakeScreen
      attr_reader :renders, :invalidations, :copies

      def initialize(events)
        @events = events
        @renders = 0
        @invalidations = 0
        @copies = []
      end

      def events = @events
      def size = Size.new(rows: 10, cols: 20)
      def chrome = BoxChrome::ASCII
      def render(_canvas) = @renders += 1
      def invalidate = @invalidations += 1
      def copy(text) = @copies << text
    end

    # An app that records the events it folds and quits when told. `redraw?` /
    # `wants_tick?` are opted into so the loop's delegation is exercised.
    class FakeApp
      attr_reader :seen

      def initialize(quit_on: nil)
        @seen = []
        @quit_on = quit_on
      end

      def view(_size) = :canvas
      def wants_tick? = false
      def redraw?(event) = event.is_a?(KeyEvent) && event.key == "\f"

      def update(event)
        @seen << event
        event.is_a?(KeyEvent) && event.key == @quit_on ? :quit : self
      end
    end

    it "renders the initial frame, then once per folded event" do
      app = FakeApp.new
      screen = FakeScreen.new(Events.new([KeyEvent.new(key: "j"), KeyEvent.new(key: "k"), EofEvent.new]))
      allow(Screen).to receive(:run).and_yield(screen)

      Runtime.new(app).run

      # both keys folded
      expect(app.seen.map(&:key)).to eq(%w[j k])
      # initial + one per key
      expect(screen.renders).to eq(3)
    end

    it "stops folding on :quit" do
      app = FakeApp.new(quit_on: "q")
      screen = FakeScreen.new(Events.new([KeyEvent.new(key: "j"), KeyEvent.new(key: "q"), KeyEvent.new(key: "x")]))
      allow(Screen).to receive(:run).and_yield(screen)

      Runtime.new(app).run

      # "x" never reached
      expect(app.seen.map(&:key)).to eq(%w[j q])
      # initial + after "j"; none after quit
      expect(screen.renders).to eq(2)
    end

    it "invalidates the screen on a redraw request (Ctrl-L)" do
      screen = FakeScreen.new(Events.new([KeyEvent.new(key: "\f"), EofEvent.new]))
      allow(Screen).to receive(:run).and_yield(screen)

      Runtime.new(FakeApp.new).run

      expect(screen.invalidations).to eq(1)
    end

    it "skips an inert tick without folding or rendering" do
      app = FakeApp.new
      screen = FakeScreen.new(Events.new([TickEvent.new, KeyEvent.new(key: "j"), EofEvent.new]))
      allow(Screen).to receive(:run).and_yield(screen)

      Runtime.new(app).run

      # the tick was dropped
      expect(app.seen.map(&:key)).to eq(%w[j])
      # initial + after "j" only
      expect(screen.renders).to eq(2)
    end

    it "drops ticks for an app that never opts in (no wants_tick?)" do
      plain = Class
        .new do
          attr_reader :folds

          def initialize = @folds = 0
          def view(_size) = :canvas
          def update(_event)
            @folds += 1
            self
          end
        end
        .new
      screen = FakeScreen.new(Events.new([TickEvent.new, EofEvent.new]))
      allow(Screen).to receive(:run).and_yield(screen)

      Runtime.new(plain).run

      # the tick was never folded
      expect(plain.folds).to eq(0)
      # only the initial frame
      expect(screen.renders).to eq(1)
    end

    it "passes a RenderContext carrying the screen size and chrome to view" do
      ctx_app = Class
        .new do
          attr_reader :got

          def view(ctx) = (@got = ctx) && :canvas
          def update(_event) = :quit
        end
        .new
      screen = FakeScreen.new(Events.new([KeyEvent.new(key: "x")]))
      allow(Screen).to receive(:run).and_yield(screen)

      Runtime.new(ctx_app).run

      expect(ctx_app.got).to be_a(RenderContext)
      expect(ctx_app.got.chrome).to be(BoxChrome::ASCII)
      expect([ctx_app.got.rows, ctx_app.got.cols]).to eq([10, 20])
    end

    it "drains a clipboard request the app queued during update (OSC 52)" do
      copier = Class
        .new do
          def view(_size) = :canvas
          def update(event)
            @pending = "copied!" if event.is_a?(KeyEvent) && event.key == "y"
            self
          end

          def take_clipboard
            text = @pending
            @pending = nil
            text
          end
        end
        .new
      screen = FakeScreen.new(Events.new([KeyEvent.new(key: "y"), EofEvent.new]))
      allow(Screen).to receive(:run).and_yield(screen)

      Runtime.new(copier).run

      expect(screen.copies).to eq(["copied!"])
    end
  end
end
