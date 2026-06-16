# frozen_string_literal: true

RSpec.describe TuiTui do
  it "has a version number" do
    expect(TuiTui::VERSION).not_to(be_nil)
  end

  it "renders text onto a canvas (smoke test)" do
    canvas = TuiTui::Canvas.new(1, 10)
    canvas.text(1, 1, "hi")
    expect(canvas.render_row(1, enabled: false)).to(eq("hi        "))
  end
end
