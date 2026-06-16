# frozen_string_literal: true

require "spec_helper"

module TuiTui
  RSpec.describe Modal do
    it "declares the protocol: handle and draw are abstract" do
      modal = Modal.new
      expect { modal.handle("x") }.to raise_error(NotImplementedError, /Modal#handle/)
      expect { modal.draw(Canvas.blank(Size.new(rows: 5, cols: 10)), nil) }
        .to raise_error(NotImplementedError, /Modal#draw/)
    end

    describe "#panel (shared framing)" do
      it "centers a framed panel and reports where content starts" do
        widget = Class
          .new(Modal) do
            define_method(:frame_on) { |canvas| panel(canvas, inner: 6, body_rows: 2) }
          end
          .new
        canvas = Canvas.blank(Size.new(rows: 12, cols: 40))

        rect, content_col = widget.frame_on(canvas)

        # box width = inner(6) + PAD*2(4) + border(2) = 12; centered in 40 cols.
        expect(rect.cols).to eq(12)
        # body_rows(2) + border(2)
        expect(rect.rows).to eq(4)
        expect(content_col).to eq(rect.col + Modal::PAD + 1)

        top = canvas.render_row(rect.row, enabled: false)
        # the framed border row
        expect(top).to include("+#{"-" * 10}+")
      end
    end
  end
end
