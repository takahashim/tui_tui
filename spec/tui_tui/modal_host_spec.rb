# frozen_string_literal: true

require "spec_helper"

module TuiTui
  RSpec.describe ModalHost do
    # A widget that resolves to :ok on "y" (key) or a left click, stays open
    # otherwise, and records what it was asked to draw.
    let(:widget) do
      Class.new do
        attr_reader :drawn

        def handle(key) = key == "y" ? :ok : nil
        def handle_mouse(event) = event.button == :left ? :clicked : nil
        def draw(_canvas, _size) = (@drawn = true)
      end.new
    end

    def key(k) = KeyEvent.new(key: k)
    def click(button) = MouseEvent.new(action: :press, button: button, row: 1, col: 1)

    it "is closed until opened" do
      host = described_class.new
      expect(host.open?).to be(false)
      expect(host.handle(key("y"))).to be_nil
    end

    it "stays open and returns nil while the widget does not resolve" do
      host = described_class.new.open(widget) { |r| r }
      expect(host.handle(key("n"))).to be_nil
      expect(host.open?).to be(true)
    end

    it "runs on_result and closes once the widget resolves a key" do
      host = described_class.new.open(widget) { |r| r == :ok ? :quit : :stay }
      expect(host.handle(key("y"))).to eq(:quit)
      expect(host.open?).to be(false)
    end

    it "routes MouseEvents to handle_mouse" do
      host = described_class.new.open(widget) { |r| r }
      expect(host.handle(click(:right))).to be_nil       # stays open
      expect(host.handle(click(:left))).to eq(:clicked)  # resolves
      expect(host.open?).to be(false)
    end

    it "defaults on_result to identity when no block is given" do
      host = described_class.new.open(widget)
      expect(host.handle(key("y"))).to eq(:ok)
    end

    it "delegates draw to the open widget" do
      host = described_class.new.open(widget)
      host.draw(:canvas, :size)
      expect(widget.drawn).to be(true)
    end
  end
end
