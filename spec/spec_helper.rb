# frozen_string_literal: true

require 'rspec/expectations'
require 'tmpdir'
require 'vimrunner'
require 'vimrunner/rspec'

class Buffer
  def initialize(vim, type)
    @file = ".fixture.#{type}"
    @vim = vim
  end

  def get_folds(content)
    levels = []
    text = content.join("\n")
    with_file text do
      for i in 1..(content.length)
        level = @vim.command 'echo foldlevel(' + i.to_s + ')'
        levels.push(level.to_i)
      end
#      # save the changes
#      sleep 0.1 if ENV['CI']
    end
    levels
  end

  def edit_and_get_folds(content, commands)
    levels = []
    text = content.join("\n")
    content = with_file text do
      # move cursor to file top
      @vim.command 'normal ggzR'
      sleep 0.05

      # run commands
      commands.each {|command| 
        @vim.command command
      }

      @vim.feedkeys ""

      # TODO: decrease to 50ms later
      content_length = (@vim.command 'echo line("$")').to_i
      @vim.command 'redraw'

      sleep 0.1
      
      # after commands executed try to get fold levels
      for i in 1..content_length
        level = @vim.command 'echo foldlevel(' + i.to_s + ')'
        levels.push(level.to_i)
      end
#      # save the changes
#      sleep 0.1 if ENV['CI']
    end

    print "fresh edited content\n"
    print content 

    levels
  end

  def messages_clear
    @vim.command ':messages clear'
  end

  def messages
    @vim.command ':messages'
  end

  private

  def with_file(content = nil)
    edit_file(content)

    yield if block_given?

    @vim.write
    IO.read(@file)
  end

  def edit_file(content)
    File.write(@file, content) if content

    @vim.edit @file
    @vim.normal ':set ft=elixir<CR>'
  end
end

class Differ
  def self.diff(result, expected)
    instance.diff(result, expected)
  end

  def self.instance
    @instance ||= new
  end

  def initialize
    @differ = RSpec::Support::Differ.new(
      object_preparer: -> (object) do
        RSpec::Matchers::Composable.surface_descriptions_in(object)
      end,
      color: RSpec::Matchers.configuration.color?
    )
  end

  def diff(result, expected)
    @differ.diff_as_object(result, expected)
  end
end

def code_parser(code) 
  offsets = []
  lines = []

  code.split("\n").each {|x|
    m = /^(\d+)(.*)$/.match(x)
    offsets.push(m[1].to_i)
    lines.push(m[2])
  }
  [offsets, lines]
end

RSpec::Matchers.define :be_elixir_fold do
  buffer = Buffer.new(VIM, :ex)

  match do |code|
    (offsets, lines) = code_parser(code)
    buffer.get_folds(lines) == offsets
  end

  failure_message do |code|
    (offsets, lines) = code_parser(code)

    buffer.messages_clear
    result = buffer.get_folds(lines)
    messages = buffer.messages

    <<~EOM
    Vim echo messages:
    #{messages}

    Diff:
    #{Differ.diff(result, offsets)}
    EOM
  end
end

RSpec::Matchers.define :be_editable_elixir_fold do |commands, levels|
  buffer = Buffer.new(VIM, :ex)

  match do |code|
    lines = code.split("\n")
    buffer.edit_and_get_folds(lines, commands) == levels
  end

  failure_message do |code|
    lines = code.split("\n")

    buffer.messages_clear
    result = buffer.edit_and_get_folds(lines, commands)
    messages = buffer.messages

    <<~EOM
    Vim echo messages:
    #{messages}

    Diff:
    #{Differ.diff(result, levels)}
    EOM
  end
end

Vimrunner::RSpec.configure do |config|
  config.reuse_server = true

  config.start_vim do
    VIM = Vimrunner.start_gvim
    VIM.add_plugin(File.expand_path('..', __dir__), 'plugin/vim-elixir-fold.vim')
    VIM
  end
end

RSpec.configure do |config|
  config.order = :random

  # Run a single spec by adding the `focus: true` option
  config.filter_run_including focus: true
  config.run_all_when_everything_filtered = true
end
