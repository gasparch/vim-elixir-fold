# vim-elixir-fold

This is a part of [Vim-Elixir-IDE](https://github.com/gasparch/vim-ide-elixir) package.

Provides automatic folding of Elixir source files.

 - function signature is shown if available
 - multiple clause heads folded together



# Installation

Drop the file in ~/.vim/plugin or ~/vimfiles/plugin folder, or if you
use pathogen into the ~/.vim/bundle/vim-elixir-fold or
~/vimfiles/bundle/vim-elixir-fold.


# Style consideration

Some function heads will **NOT** be folded at all.

Function with arguments is expected to have braces around arguments list. If function does not have arugments, braces can be omitted.


So please rewrite this

```elixir
def func arg do
  :ok
end
```

to this form:

```elixir
def func(arg) do
  :ok
end
```

This is recognized correctly:
```elixir
def func do
  true
end
```


## Development

Setup Ruby 2.3.1 environment using [rbenv](https://github.com/rbenv/rbenv#installation).

To run the tests you can run `bundle exec rspec`.

To spawn an interactive Vim instance with the configs from this repo use `bin/spawn_vim`

## TODO

 - profiling/speedup

