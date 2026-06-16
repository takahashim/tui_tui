# frozen_string_literal: true

require "spec_helper"
require "stringio"

module TuiTui
  RSpec.describe EventStream do
    # A stand-in size source (responds to #size), like TerminalSize.
    SizeSource = Data.define(:size)

    it "emits resize before polling input" do
      stream = EventStream.new(input: StringIO.new, size: SizeSource.new(size: Size.new(rows: 40, cols: 120)))

      stream.resized!

      expect(stream.next_event).to eq(ResizeEvent.new(size: Size.new(rows: 40, cols: 120)))
    end

    it "emits tick when no input is ready" do
      reader, writer = IO.pipe
      begin
        stream = EventStream.new(input: reader, size: SizeSource.new(size: Size.new(rows: 1, cols: 1)))

        expect(stream.next_event(tick: 0)).to eq(TickEvent.new)
      ensure
        reader.close unless reader.closed?
        writer.close unless writer.closed?
      end
    end

    it "wraps a key read from ready input" do
      key_reader = instance_double(KeyReader, read_all: ["j"])
      allow(KeyReader).to receive(:new).and_return(key_reader)
      allow(IO).to receive(:select).and_return([[]])

      reader, writer = IO.pipe
      begin
        stream = EventStream.new(input: reader, size: SizeSource.new(size: Size.new(rows: 1, cols: 1)))

        expect(stream.next_event(tick: 0)).to eq(KeyEvent.new(key: "j"))
      ensure
        reader.close unless reader.closed?
        writer.close unless writer.closed?
      end
    end

    it "passes mouse events through" do
      mouse = MouseEvent.new(action: :press, button: :left, col: 2, row: 3)
      key_reader = instance_double(KeyReader, read_all: [mouse])
      allow(KeyReader).to receive(:new).and_return(key_reader)
      allow(IO).to receive(:select).and_return([[]])

      reader, writer = IO.pipe
      begin
        stream = EventStream.new(input: reader, size: SizeSource.new(size: Size.new(rows: 1, cols: 1)))

        expect(stream.next_event(tick: 0)).to eq(mouse)
      ensure
        reader.close unless reader.closed?
        writer.close unless writer.closed?
      end
    end

    it "drains a batched burst one event per call (without re-reading)" do
      m1 = MouseEvent.new(action: :wheel, button: :wheel_down, col: 1, row: 1)
      m2 = MouseEvent.new(action: :wheel, button: :wheel_down, col: 1, row: 2)
      key_reader = instance_double(KeyReader, read_all: [m1, m2])
      allow(KeyReader).to receive(:new).and_return(key_reader)
      allow(IO).to receive(:select).and_return([[]])

      reader, writer = IO.pipe
      begin
        stream = EventStream.new(input: reader, size: SizeSource.new(size: Size.new(rows: 1, cols: 1)))

        expect(stream.next_event(tick: 0)).to eq(m1)
        # from the queue, no second read_all
        expect(stream.next_event(tick: 0)).to eq(m2)
        expect(key_reader).to have_received(:read_all).once
      ensure
        reader.close unless reader.closed?
        writer.close unless writer.closed?
      end
    end

    it "emits eof when the key reader reaches eof" do
      key_reader = instance_double(KeyReader, read_all: nil)
      allow(KeyReader).to receive(:new).and_return(key_reader)
      allow(IO).to receive(:select).and_return([[]])

      reader, writer = IO.pipe
      begin
        stream = EventStream.new(input: reader, size: SizeSource.new(size: Size.new(rows: 1, cols: 1)))

        expect(stream.next_event(tick: 0)).to eq(EofEvent.new)
      ensure
        reader.close unless reader.closed?
        writer.close unless writer.closed?
      end
    end
  end
end
