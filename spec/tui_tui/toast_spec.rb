# frozen_string_literal: true

require "spec_helper"

module TuiTui
  RSpec.describe Toast do
    # A controllable clock so expiry is deterministic (no sleeping).
    def clock_at(time) = -> { time }

    it "is live until its lifetime elapses, then expired" do
      now = 0.0
      toast = Toast.new("hi", seconds: 2.0, clock: -> { now })

      expect(toast.expired?).to be(false)
      now = 1.99
      expect(toast.expired?).to be(false)
      now = 2.0
      expect(toast.expired?).to be(true)
    end

    it "draws a centered, padded message while live" do
      toast = Toast.new("done", seconds: 1.0, clock: clock_at(0.0))
      canvas = Canvas.new(5, 20)

      toast.draw(canvas, Size.new(rows: 5, cols: 20), style: Style.new)

      # size.rows - 2
      row = canvas.render_row(3, enabled: false)
      expect(row).to include(" done ")
      # centered, not flush left
      expect(row.index("done")).to be > 1
    end

    it "draws at any requested 3x3 position" do
      cases = {
        top_left: [1, 1],
        top_center: [1, 8],
        top_right: [1, 15],
        middle_left: [3, 1],
        middle_center: [3, 8],
        middle_right: [3, 15],
        bottom_left: [4, 1],
        bottom_center: [4, 8],
        bottom_right: [4, 15]
      }

      cases.each do |position, (row, col)|
        toast = Toast.new("done", position: position, seconds: 1.0, clock: clock_at(0.0))
        canvas = Canvas.new(6, 20)

        toast.draw(canvas, Size.new(rows: 6, cols: 20), style: Style.new)

        expect(canvas.render_row(row, enabled: false)[col - 1, 6]).to eq(" done ")
      end
    end

    it "accepts center as an alias for middle_center" do
      toast = Toast.new("done", position: :center, seconds: 1.0, clock: clock_at(0.0))
      canvas = Canvas.new(5, 20)

      toast.draw(canvas, Size.new(rows: 5, cols: 20), style: Style.new)

      expect(canvas.render_row(3, enabled: false)[7, 6]).to eq(" done ")
    end

    it "rejects an unknown position" do
      expect { Toast.new("done", position: :upperish, clock: clock_at(0.0)) }
        .to raise_error(ArgumentError, /unknown toast position/)
    end

    it "draws nothing once expired (a forgotten toast still vanishes)" do
      now = 0.0
      toast = Toast.new("done", seconds: 1.0, clock: -> { now })
      canvas = Canvas.new(5, 20)
      now = 2.0

      toast.draw(canvas, Size.new(rows: 5, cols: 20), style: Style.new)
      expect(canvas.render_row(3, enabled: false).strip).to eq("")
    end
  end
end
