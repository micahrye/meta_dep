defmodule Mix.Tasks.MetaDep do
  @moduledoc """
  Cmdline Options:
    * `-l, --licences` returns all licenses for all deps
    * `-v, --verbose` returns all meta data for all deps
    * `-d, --dep` return meta data for specified dependency
    * `-p, --path` path to directory containing deps directories, returns license info for all deps
    * `-ld` returns license info for specific dependency
    * `-vd` returns all meta data for specific dependency

  Usage:
  ```
  $ mix meta_dep -p ./deps -ld bunt
  {"bunt", %{"Licenses" => "MIT"}}
  ```
  """

  @shortdoc """
  List meta data for dependencies
  """

  use Mix.Task

  @spec run([binary()]) :: :ok
  def run(argv) do
    MetaDep.main(argv)
  end
end
