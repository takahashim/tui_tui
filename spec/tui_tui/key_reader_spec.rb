# frozen_string_literal: true

require "spec_helper"

module TuiTui
  # The pure escape-sequence parser (the I/O side, `read`, needs a real tty).
  RSpec.describe KeyReader do
    subject(:reader) { described_class.new }

    it "arrows" do
      expect(reader.decode_escape("[A")).to eq(:up)
      expect(reader.decode_escape("[B")).to eq(:down)
      expect(reader.decode_escape("[C")).to eq(:right)
      expect(reader.decode_escape("[D")).to eq(:left)
    end

    it "paging and home end" do
      expect(reader.decode_escape("[5~")).to eq(:pgup)
      expect(reader.decode_escape("[6~")).to eq(:pgdn)
      expect(reader.decode_escape("[H")).to eq(:home)
      expect(reader.decode_escape("[F")).to eq(:end)
    end

    it "SS3 cursor forms (application-cursor mode / tmux)" do
      expect(reader.decode_escape("OA")).to eq(:up)
      expect(reader.decode_escape("OB")).to eq(:down)
      expect(reader.decode_escape("OC")).to eq(:right)
      expect(reader.decode_escape("OD")).to eq(:left)
      expect(reader.decode_escape("OH")).to eq(:home)
      expect(reader.decode_escape("OF")).to eq(:end)
    end

    it "delete and shift-tab" do
      expect(reader.decode_escape("[3~")).to eq(:delete)
      expect(reader.decode_escape("[Z")).to eq(:backtab)
    end

    it "lone escape" do
      expect(reader.decode_escape(nil)).to eq(:escape)
      expect(reader.decode_escape("")).to eq(:escape)
    end

    it "unknown sequence is escape" do
      expect(reader.decode_escape("[99~")).to eq(:escape)
    end

    # Modified specials (xterm "1;<mod>" form) become composite symbols, so they
    # no longer collapse to :escape (which would e.g. cancel a modal by mistake).
    describe "modified special keys" do
      it "decodes modified arrows" do
        # Ctrl+Right
        expect(reader.decode_escape("[1;5C")).to eq(:ctrl_right)
        # Shift+Up
        expect(reader.decode_escape("[1;2A")).to eq(:shift_up)
        # Alt+Left
        expect(reader.decode_escape("[1;3D")).to eq(:alt_left)
        expect(reader.decode_escape("[1;6B")).to eq(:ctrl_shift_down)
      end

      it "decodes modified Home/End and tilde keys" do
        expect(reader.decode_escape("[1;5H")).to eq(:ctrl_home)
        expect(reader.decode_escape("[1;2F")).to eq(:shift_end)
        expect(reader.decode_escape("[3;5~")).to eq(:ctrl_delete)
      end

      it "orders modifiers ctrl, alt, shift" do
        # mod 8 = all three
        expect(reader.decode_escape("[1;8C")).to eq(:ctrl_alt_shift_right)
      end

      it "without modifiers (mod 1) yields the bare key" do
        expect(reader.decode_escape("[1;1C")).to eq(:right)
      end
    end

    describe "SGR mouse reports" do
      it "decodes a left-button press" do
        expect(reader.decode_escape("[<0;40;12M")).to(
          eq(MouseEvent.new(action: :press, button: :left, col: 40, row: 12))
        )
      end

      it "decodes a release (lowercase m terminator)" do
        expect(reader.decode_escape("[<0;40;12m")).to(
          eq(MouseEvent.new(action: :release, button: :left, col: 40, row: 12))
        )
      end

      it "decodes a drag (motion bit 32 set)" do
        expect(reader.decode_escape("[<32;41;12M")).to(
          eq(MouseEvent.new(action: :drag, button: :left, col: 41, row: 12))
        )
      end

      it "decodes wheel up and down (bit 64)" do
        expect(reader.decode_escape("[<64;5;5M")).to(
          eq(MouseEvent.new(action: :wheel, button: :wheel_up, col: 5, row: 5))
        )
        expect(reader.decode_escape("[<65;5;5M")).to(
          eq(MouseEvent.new(action: :wheel, button: :wheel_down, col: 5, row: 5))
        )
      end

      it "decodes the first event when reports are batched" do
        expect(reader.decode_escape("[<32;41;12M[<32;42;12M").action).to eq(:drag)
      end

      # A fast wheel batches several reports in one read; decode_escape_events
      # returns them all so none are dropped (the lag/responsiveness fix).
      it "decodes every report in a batched burst" do
        events = reader.decode_escape_events("[<64;5;5M[<64;6;6M[<64;7;7M")
        expect(events.map(&:action)).to eq(%i[wheel wheel wheel])
        expect(events.map(&:row)).to eq([5, 6, 7])
      end

      it "handles large coordinates beyond the legacy 223 cap" do
        expect(reader.decode_escape("[<0;240;300M")).to(
          eq(MouseEvent.new(action: :press, button: :left, col: 240, row: 300))
        )
      end
    end

    # The I/O side: a fake console returning one getch and (for ESC) the tail.
    describe "#read" do
      it "returns a literal key as-is" do
        io = double("io", getch: "j")

        expect(reader.read(io)).to eq("j")
      end

      it "decodes an escape sequence from the tail" do
        up = double("io", getch: "\e")
        down = double("io", getch: "\e")
        allow(up).to receive(:read_nonblock).with(KeyReader::ESCAPE_TAIL_BYTES, exception: false).and_return("[A")
        allow(down).to receive(:read_nonblock).with(KeyReader::ESCAPE_TAIL_BYTES, exception: false).and_return("OB")

        expect(reader.read(up)).to eq(:up)
        expect(reader.read(down)).to eq(:down)
      end

      it "is :escape for a lone ESC with no tail" do
        io = double("io", getch: "\e")
        allow(io).to(
          receive(:read_nonblock).with(KeyReader::ESCAPE_TAIL_BYTES, exception: false).and_return(:wait_readable)
        )

        expect(reader.read(io)).to eq(:escape)
      end

      it "returns nil at EOF (getch nil)" do
        io = double("io", getch: nil)

        expect(reader.read(io)).to be_nil
      end

      # Raw mode hands a multibyte char to getch one byte at a time; read must
      # reassemble it so IME-committed Japanese doesn't arrive as stray bytes.
      describe "multibyte (IME) input" do
        it "assembles a UTF-8 character from its bytes" do
          feed = lambda do |string|
            bytes = string.b.chars
            io = double("io")
            allow(io).to receive(:getch) { bytes.shift }
            allow(io).to receive(:read_nonblock) do |count, exception:|
              bytes.empty? ? :wait_readable : bytes.shift(count).join
            end

            io
          end

          expect(reader.read(feed.call("あ"))).to eq("あ")
          expect(reader.read(feed.call("漢"))).to eq("漢")
          expect(reader.read(feed.call("🚀"))).to eq("🚀")
        end

        it "passes through a character getch already delivered whole" do
          io = double("io", getch: "あ")

          expect(reader.read(io)).to eq("あ")
        end

        it "collapses a stray/incomplete byte to :unknown (no partial char leaks)" do
          io = double("io", getch: "\xE3".b)
          allow(io).to receive(:read_nonblock).with(1, exception: false).and_return(:wait_readable)

          expect(reader.read(io)).to eq(:unknown)
        end

        it "still reads plain ASCII unchanged" do
          io = double("io", getch: "j")

          expect(reader.read(io)).to eq("j")
        end
      end
    end
  end

  RSpec.describe KeyIntent do
    it "maps shared navigation keys" do
      expect(described_class.for(:up)).to eq(:up)
      expect(described_class.for("k")).to eq(:up)
      expect(described_class.for(:down)).to eq(:down)
      expect(described_class.for("j")).to eq(:down)
      expect(described_class.for(:home)).to eq(:top)
      expect(described_class.for("G")).to eq(:bottom)
    end

    it "maps shared cancel keys" do
      expect(described_class.for(:escape)).to eq(:cancel)
      expect(described_class.for("q")).to eq(:cancel)
      expect(described_class.for(KeyCode::CTRL_C)).to eq(:cancel)
    end

    it "returns nil for widget-specific keys" do
      expect(described_class.for(" ")).to be_nil
      expect(described_class.for("b")).to be_nil
    end
  end
end
