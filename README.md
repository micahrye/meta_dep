# MetaDep
MetaDep is an library application that can also be used as an escript
or mix task. MetaDep is a convenience app that allows you to list
meta information about all project dependencies. It supports a number
of cmdline arguments

Full documentation can be found at https://hexdocs.pm/meta_dep/0.1.0

## Installation

The package can be installed by adding `meta_dep` to your list of
dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:meta_dep, "~> 0.1.0", only: :dev, runtime: false}
  ]
end
```

## Mix Task

If `meta_dep` has been added to your project you can run its mix task from the
cmdline as follows:

```bash
$ mix meta_dep
```

See `MetaDep` for complete documentation and usage examples.

## Escript

To build and install as an escript do the following:

```bash
$ mix escript.build
```

This should build the escript `meta_dep` in your cwd. You can install the
escript locally be doing the following:

```bash
$ mix escript.install
```