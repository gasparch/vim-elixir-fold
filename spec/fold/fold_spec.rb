# frozen_string_literal: true

require 'spec_helper'

describe 'folding simple functions' do
  it "fold simple function" do
    expect(<<~EOF).to be_elixir_fold
1   def asd() do
1      something
1   end
    EOF
  end

  it "fold simple function w/spaces" do
    expect(<<~EOF).to be_elixir_fold
1   def asd() do
1
1      something()
1      {:ok, 123}
1
1   end
    EOF
  end

  it "fold simple function w/if+case" do
    expect(<<~EOF).to be_elixir_fold
1   def asd() do
1
1     if true do
1       :ok
1     else
1       :not_ok
1     end
1
1     case %{} do
1       %{:asd => value} -> value
1     end
1   end
    EOF
  end

  it "fold functions with comments" do
    expect(<<~EOF).to be_elixir_fold
1   def asd1() do#
1      something1
1   end#
0
1   def asd2() do
1      something2
1   end
    EOF
  end

  it "no fold one-liner" do
    expect(<<~EOF).to be_elixir_fold
0 defmodule Test do
0   def asd1(), do: true
0
1   def asd2() do
1      something2
1   end
0 end
    EOF
  end

  it "fold one-liner w/next body" do
    expect(<<~EOF).to be_elixir_fold
0 defmodule Test do
1   def asd1(), do: true
1
1   def asd1() do
1      something2
1   end
0 end
    EOF
  end

  it "fold one-liner w/next body which has 'when' " do
    expect(<<~EOF).to be_elixir_fold
0 defmodule Test do
1   def asd1(), do: true
1
1   def asd1(v) when is_atom(v) do
1      something2
1   end
0 end
    EOF
  end

#  WARNING: do NOT fix it on purpose, we want to enforce
#  code style with braces around arguments in function definition!
#
#  it "fold one-liner w/next body without braces " do
#    expect(<<~EOF).to be_elixir_fold
#0 defmodule Test do
#1   def asd1(), do: true
#1
#1   def asd1 v  when is_atom(v) do
#1      something2
#1   end
#0 end
#    EOF
#  end

  it "fold body w/next one-liner" do
    expect(<<~EOF).to be_elixir_fold
0 defmodule Test do
1   def asd1() do
1      something2
1   end
1
1   def asd1(), do: true
0 end
    EOF
  end

  it "fold bodies w/one-liner in between" do
    expect(<<~EOF).to be_elixir_fold
0 defmodule Test do
1   def asd1() do
1      something2
1   end
1
1   def asd1(), do: true
1
1   def asd1() do
1      something2
1   end
0 end
    EOF
  end

  it "fold body w/one-liner but not next fun" do
    expect(<<~EOF).to be_elixir_fold
0 defmodule Test do
1   def asd1() do
1      something2
1   end
1
1   def asd1(), do: true
0
1   def asd2() do
1      something2
1   end
0 end
    EOF
  end

  it "fold one-line default definition w/next body" do
    expect(<<~EOF).to be_elixir_fold
0 defmodule Test do
1   def asd1(var1 \\ "")
1
1   def asd1(var1) do
1      something2
1   end
0 end
    EOF
  end

  it "fold 2 clauses together" do
    expect(<<~EOF).to be_elixir_fold
1   def asd1() do
1      something1
1   end
1
1   def asd1() do
1      something2
1   end
    EOF
  end

  it "fold 2 clauses together and comments" do
    expect(<<~EOF).to be_elixir_fold
0 defmodule Test do
1   def asd1() do
1      something1
1   end
1
1   # some comment
1
1   def asd1() do
1      something2
1   end
0 end
    EOF
  end

  it "fold function head w/o argumetns and braces" do
    expect(<<~EOF).to be_elixir_fold
0 defmodule Test do
1   def   asd1    do
1     true
1   end
0 end
    EOF
  end

  it "no fold one-liner function head w/o argumetns and braces" do
    expect(<<~EOF).to be_elixir_fold
0 defmodule Test do
0   def asd1, do: true
0 end
    EOF
  end

  it "handle_call clauses do not fold together" do
    expect(<<~EOF).to be_elixir_fold
0 defmodule Test do
1   def handle_call() do
1      something1
1   end
0
1   def handle_call() do
1      something2
1   end
0 end
    EOF
  end

  it "handle_cast clauses do not fold together" do
    expect(<<~EOF).to be_elixir_fold
0 defmodule Test do
1   def handle_cast() do
1      something1
1   end
0
1   def handle_cast() do
1      something2
1   end
0 end
    EOF
  end

  it "handle_info clauses do not fold together" do
    expect(<<~EOF).to be_elixir_fold
0 defmodule Test do
1   def handle_info() do
1      something1
1   end
0
1   def handle_info() do
1      something2
1   end
0 end
    EOF
  end

  it "fold 2 functions separately" do
    expect(<<~EOF).to be_elixir_fold
1   def asd1() do
1      something1
1   end
0
1   def asd2() do
1      something2
1   end
    EOF
  end

  it "fold 2 functions separately + comment" do
    expect(<<~EOF).to be_elixir_fold
1   def asd1() do
1      something1
1   end
0
0   # some comment
1   def asd2() do
1      something2
1   end
    EOF

    expect(<<~EOF).to be_elixir_fold
1   def asd1() do
1      something1
1   end
0
0   # some comment
0
1   def asd2() do
1      something2
1   end
    EOF
  end

  it "fold simple function w/if+case in module" do
    expect(<<~EOF).to be_elixir_fold
0   defmodule Test do
1     def asd() do
1
1       if true do
1         :ok
1       else
1         :not_ok
1       end
1
1       case %{} do
1         %{:asd => value} -> value
1       end
1     end
0   end
    EOF
  end

  it "fold function with case" do
    expect(<<~EOF).to be_elixir_fold
0   defmodule Test do
1     def fix(data) do
1       case data do
1       end
1     end
0   end
    EOF
  end

  it "fold function in a module" do
    expect(<<~EOF).to be_elixir_fold
0   defmodule Test do
1     def asd() do
1        something
1     end
0   end
    EOF
  end

  it "fold function in a two modules" do
    expect(<<~EOF).to be_elixir_fold
0   defmodule Test do
1     def asd4() do
1        something
1     end
0   end
0
0   defmodule Test1 do
1     def asd5() do
1        something
1     end
0   end
    EOF
  end

  it "fold nested functions in a module" do
    expect(<<~EOF).to be_elixir_fold
0   defmodule Test do
1     def asd() do
1        something
1     end
0
1     defp asd2(v1, v2) do
2       def asd3 do
3         def asd4(v4) do
3           true
3         end
2
2         true
2
2       end
1     end
0   end
    EOF
  end

  it "fold ExUnit test definition" do
    expect(<<~EOF).to be_elixir_fold
0   defmodule Test do
1      test "truth" do
1        assert 1 == 1
1      end
0 
1      test "truth" do
1        assert 1 == 1
1      end
0   end
    EOF
  end

  it "fold ExUnit test group definition" do
    expect(<<~EOF).to be_elixir_fold
0   defmodule Test do
1     describe "test group" do
2        test "truth" do
2          assert 1 == 1
2        end
1
2        test "truth" do
2          assert 1 == 1
2        end
1     end
0   end
    EOF
  end





  ########################################################################
  # editing folds

  it "edit function text in a module" do
    commands = [
      'normal 2joaddline',
      'normal =='
    ]

    levels = [0,1,1,1,1,0]

    expect(<<~EOF).to be_editable_elixir_fold(commands, levels)
    defmodule Test do
      def asd() do
          something
      end
    end
    EOF
  end

  it "add function text in a module" do
    commands = [
      'exec "normal 3jodef name do"',
      'normal ==',
      'exec "normal oend"',
      'normal =='
    ]

    levels = [0,1,1,1,1,1,0]

    expect(<<~EOF).to be_editable_elixir_fold(commands, levels)
    defmodule Test do
      def asd() do
          something
      end
    end
    EOF
  end

  it "add header part 'def'" do
    commands = [
      'exec "normal 3jodef"',
      'normal =='
    ]

    levels = [0,1,1,1,0,0]

    expect(<<~EOF).to be_editable_elixir_fold(commands, levels)
    defmodule Test do
      def asd() do
          something
      end
    end
    EOF
  end

  it "add header part 'def '" do
    commands = [
      'exec "normal 3jodef "',
      'normal =='
    ]

    levels = [0,1,1,1,0,0]

    expect(<<~EOF).to be_editable_elixir_fold(commands, levels)
    defmodule Test do
      def asd() do
          something
      end
    end
    EOF
  end

  it "add function text in a module with empty line" do
    commands = [
      'exec "normal 3jo"',
      'exec "normal o  def name do"',
      'exec "normal o  end"'
    ]

    levels = [0,1,1,1,0,1,1,0]

    expect(<<~EOF).to be_editable_elixir_fold(commands, levels)
    defmodule Test do
      def asd() do
          something
      end
    end
    EOF
  end

  it "add function text in a module with empty line" do
    commands = [
      'exec "normal 3jo"',
      'exec "normal o  def name do"',
      'exec "normal o  end"'
    ]

    levels = [0,1,1,1,0,1,1,0]

    expect(<<~EOF).to be_editable_elixir_fold(commands, levels)
    defmodule Test do
      def asd() do
          something
      end
    end
    EOF
  end

  it "add nested functions, lines 1-2" do
    commands = [
      'exec "normal 3jo"',
      'exec "normal o  defp asd2(v1, v2) do"',
      'exec "normal o    def asd3 do"',
      'exec "normal o"'
    ]

    levels = [0,1,1,1,0,1,2,2,2]

    expect(<<~EOF).to be_editable_elixir_fold(commands, levels)
    defmodule Test do
      def asd() do
          something
      end
    end
    EOF
  end

  it "add nested functions, lines 1-3" do
    commands = [
      'exec "normal 3jo"',
      'exec "normal o  defp asd2(v1, v2) do"',
      'exec "normal o    def asd3 do"',
      'exec "normal o      def asd4(v4) do"',
    ]

    levels = [0,1,1,1,0,1,2,3,3]

    expect(<<~EOF).to be_editable_elixir_fold(commands, levels)
    defmodule Test do
      def asd() do
          something
      end
    end
    EOF
  end

  it "add nested functions, lines 1-4" do
    commands = [
      'exec "normal 3jo"',
      'exec "normal o  defp asd2(v1, v2) do"',
      'exec "normal o    def asd3 do"',
      'exec "normal o      def asd4(v4) do"',
      'exec "normal o      end"',
    ]

    levels = [0,1,1,1,0,1,2,3,3,2]

    expect(<<~EOF).to be_editable_elixir_fold(commands, levels)
    defmodule Test do
      def asd() do
          something
      end
    end
    EOF
  end

  it "add nested functions, lines 1-5" do
    commands = [
      'exec "normal 3jo"',
      'exec "normal o  defp asd2(v1, v2) do"',
      'exec "normal o    def asd3 do"',
      'exec "normal o      def asd4(v4) do"',
      'exec "normal o      end"',
      'exec "normal o        true"',
      'exec "normal o    end"',
    ]

    levels = [0,1,1,1,0,1,2,3,3,2,2,1]

    expect(<<~EOF).to be_editable_elixir_fold(commands, levels)
    defmodule Test do
      def asd() do
          something
      end
    end
    EOF
  end

  it "add nested functions" do
    commands = [
      'exec "normal 3jo"',
      'exec "normal o  defp asd2(v1, v2) do"',
      'exec "normal o    def asd3 do"',
      'exec "normal o      def asd4(v4) do"',
      'exec "normal o      end"',
      'exec "normal o    end"',
      'exec "normal o  end"'
    ]

    levels = [0,1,1,1,0,1,2,3,3,2,1,0]

    expect(<<~EOF).to be_editable_elixir_fold(commands, levels)
    defmodule Test do
      def asd() do
          something
      end
    end
    EOF
  end





end
