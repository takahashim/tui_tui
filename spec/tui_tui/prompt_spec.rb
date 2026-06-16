# frozen_string_literal: true

require "spec_helper"

module TuiTui
  RSpec.describe Prompt do
    it "inserts printable characters" do
      prompt = Prompt.new("Find:")
      "abc".each_char { |c| expect(prompt.handle(c)).to be_nil }
      expect(prompt.value).to eq("abc")
    end

    it "enter returns ok with value" do
      prompt = Prompt.new("Find:", value: "hello")
      expect(prompt.handle("\r")).to eq([:ok, "hello"])
    end

    it "escape cancels" do
      expect(Prompt.new("Find:").handle(:escape)).to eq(:cancel)
    end

    it "backspace deletes before cursor" do
      prompt = Prompt.new("Find:", value: "abc")
      prompt.handle(KeyCode::BACKSPACE)
      expect(prompt.value).to eq("ab")
    end

    it "cursor movement and mid insert" do
      prompt = Prompt.new("Find:", value: "ac")
      # cursor between a and c
      prompt.handle(:left)
      # insert b at the cursor
      prompt.handle("b")
      expect(prompt.value).to eq("abc")
    end

    it "delete removes the character at the cursor (forward delete)" do
      prompt = Prompt.new("Find:", value: "abc")
      # cursor before "a"
      prompt.handle(:home)
      # removes "a"
      prompt.handle(:delete)
      expect(prompt.value).to eq("bc")
      # cursor at end
      prompt.handle(:end)
      # nothing to delete forward
      prompt.handle(:delete)
      expect(prompt.value).to eq("bc")
    end

    it "control keys do not insert" do
      prompt = Prompt.new("Find:")
      prompt.handle("\t")
      expect(prompt.value).to eq("")
    end

    it "inserts wide characters" do
      prompt = Prompt.new("検索:")
      prompt.handle("あ")
      expect(prompt.value).to eq("あ")
    end

    describe "grapheme-cluster editing (emoji modifiers / combining marks)" do
      it "moves and deletes a multi-codepoint emoji as one unit" do
        # thumbs-up + skin-tone modifier, then x
        prompt = Prompt.new("Find:", value: "👍🏽x")

        # one move skips the whole "👍🏽" cluster's neighbour (x)
        prompt.handle(:left)
        # deletes the whole emoji cluster, not just the modifier
        prompt.handle(:backspace)
        expect(prompt.value).to eq("x")
      end

      it "keeps a base+combining-mark sequence as a single grapheme" do
        # é (e + combining acute) then x
        prompt = Prompt.new("Find:", value: "éx")
        prompt.handle(:home)
        # removes the whole "é", not just the 'e'
        prompt.handle(:delete)
        expect(prompt.value).to eq("x")
      end

      it "merges a combining mark typed after its base into one grapheme" do
        prompt = Prompt.new("Find:")
        prompt.handle("e")
        # combining acute typed separately
        prompt.handle("́")
        expect(prompt.value).to eq("é")
        # one delete removes the whole "é"
        prompt.handle(:backspace)
        expect(prompt.value).to eq("")
      end
    end

    it "draw renders label and value with ascii frame" do
      size = Size.new(rows: 10, cols: 40)
      canvas = Canvas.blank(size)
      prompt = Prompt.new("Find:", value: "abc")
      prompt.draw(canvas, size)
      screen = (1..10).map { |r| canvas.render_row(r, enabled: false) }.join("\n")
      expect(screen).to include("Find:")
      expect(screen).to include("abc")
      expect(screen).to include("+--")
    end
  end
end
