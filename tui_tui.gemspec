# frozen_string_literal: true

require_relative "lib/tui_tui/version"

Gem::Specification.new do |spec|
  spec.name = "tui_tui"
  spec.version = TuiTui::VERSION
  spec.authors = ["takahashim"]
  spec.email = ["takahashimm@gmail.com"]

  spec.summary = "A tiny, dependency-free TUI runtime for modern terminals."
  spec.description = "TuiTui is a small terminal-UI framework: a width-aware canvas, " \
                     "a diffing renderer, an Elm-style runtime loop, and composable " \
                     "widgets (modals, lists, prompts). Its only dependency is io/console."
  spec.homepage = "https://github.com/takahashim/tui_tui"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"
  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/takahashim/tui_tui"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
end
