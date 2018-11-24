defmodule MetaDep do
  @moduledoc """
  MetaDep is an library application that can also be used as an escript
  or mix task.

  MetaDep is a convenience app that allows you to list meta information about
  all project dependencies. It supports a number of cmdline arguments and
  can list the following for each dependency:
    * Licenses - A list of licenses such as MIT, BSD, etc.
    * Maintainers - Maintanters of the project
    * Repo - Link to the git repo

  ## Cmdline Options
    * `-l, --licences` returns all licenses for all deps
    * `-v, --verbose` returns all meta data for all deps
    * `-d, --dep` return meta data for specified dependency
    * `-p, --path` path to directory containing deps directories, returns license info for all deps
    * `-ld` returns license info for specific dependency
    * `-vd` returns all meta data for specific dependency

  ## Usage:
  ```
  $ mix meta_dep -p ./deps -ld bunt
  {"bunt", %{"Licenses" => "MIT, Apache2"}}

  $ mix meta_dep -p ./deps -vd bunt
  {"bunt",
    %{
      "Licenses" => "MIT, Apache2",
      "Maintainers" => "René Föhring",
      "Repo" => "https://github.com/rrrene/bunt"
    }}

  $ mix meta_dep -l
    {"bunt", %{"Licenses" => "MIT, Apache2"}}
    {"chumak", %{"Licenses" => "MPLv2"}}
    {"cowboy", %{"Licenses" => "ISC"}}
    {"cowlib", %{"Licenses" => "ISC"}}
    {"jason", %{"Licenses" => "Apache 20"}}
    {"licensir", %{"Licenses" => "MIT"}}
    {"mime", %{"Licenses" => "Apache 2"}}
    {"plug", %{"Licenses" => "Apache 2"}}
    {"plug_cowboy", %{"Licenses" => "Apache 2"}}
    {"plug_crypto", %{"Licenses" => "Apache 2"}}
    {"ranch", %{"Licenses" => "ISC"}}
    {"sweet_xml", %{"Licenses" => "MIT"}}
  ```
  """

  @cruft_pattern ~r/[^a-zA-Z\d\s,\p{L}:\.]/u
  @cruft_url_pattern ~r/[^a-zA-Z\d\s,\p{L}:\/\.\-\_]/u
  @utf_pattern ~r/utf8/
  @leading_path ~r/.*deps\//
  @end_of_term "}."

  @doc """
  The function main is the entry point for escript and mix task and takes
  cmdline arguments in the form of [String.t()]
  """
  @spec main([String.t()]) :: :ok
  def main(argv) do
    IO.puts("cmdline args = #{inspect(argv)}")
    opts = options(argv)
    path = opts["path"] || "./deps/"
    dep = opts["dep"] || "*"
    licences = opts["licences"]
    # If verbose or licences arg not given we default to `verbose = true`
    verbose = opts["verbose"] || not licences
    meta_dep_map = extract_licenses(path, dep)

    cond do
      verbose == true -> meta_dep_map
      licences == true -> drop_fields(meta_dep_map, ["Maintainers", "Repo"])
      true -> meta_dep_map
    end
    |> print_to_console()
  end

  @doc """
  The function options takes the cmdline arguments and parses them to
  options for application.
  """
  @spec options([String.t()]) :: map()
  def options(argv) do
    parsed_args =
      OptionParser.parse(
        argv,
        aliases: [l: :licences, v: :verbose, d: :dep, p: :path],
        strict: [
          licences: :boolean,
          verbose: :boolean,
          dep: :string,
          path: :string
        ]
      )

    args = elem(parsed_args, 0)
    IO.puts("valid args = #{inspect(args)}")

    opts = %{
      "path" => nil,
      "dep" => nil,
      "licences" => false,
      "verbose" => false
    }

    opts =
      Enum.reduce(Keyword.keys(args), opts, fn key, acc ->
        Map.put(acc, to_string(key), Keyword.get(args, key, nil))
      end)

    case opts["path"] do
      nil ->
        opts

      path ->
        %{opts | "path" => String.replace(path <> "/", ~r/\/+/, "/")}
    end
  end

  @spec extract_licenses(String.t(), String.t()) :: map()
  def extract_licenses(path, dep \\ "*") do
    # Make sure the dependencies are loaded
    IO.puts("path <> dep = #{path <> dep}")

    Path.wildcard(path <> dep)
    |> Enum.map(fn dep ->
      {:ok, content} = File.read(dep <> "/hex_metadata.config")
      content = String.replace(content, "\n", "")
      dep_name = String.replace(dep, @leading_path, "")

      content
      |> String.split(@end_of_term)
      |> Enum.map(fn line -> {dep_name, extract(line)} end)
      |> Enum.filter(fn x -> if elem(x, 1) == "", do: false, else: elem(x, 1) end)
    end)
    |> Enum.flat_map(& &1)
    |> Enum.reduce(
      %{},
      fn dep, acc ->
        meta_dep_map(acc, dep)
      end
    )
  end

  @spec extract_licenses() :: map()
  def extract_licenses() do
    extract_licenses("./deps/", "*")
  end

  @spec meta_dep_map(map(), tuple()) :: map()
  def meta_dep_map(m, dep) do
    key = elem(dep, 0)
    nested_key = elem(elem(dep, 1), 0)
    value = elem(elem(dep, 1), 1)

    md =
      case Map.has_key?(m, key) do
        true ->
          m

        false ->
          Map.put(m, key, %{})
      end

    put_in(md, [key, nested_key], value)
  end

  @spec print_to_console(map()) :: :ok
  def print_to_console(meta_dep) do
    IO.puts("")
    Enum.each(meta_dep, fn dep -> IO.inspect(dep) end)
    IO.puts("")
  end

  @spec extract(String.t()) :: {String.t(), String.t()}
  defp extract("Licenses" <> dirty_license) do
    {"Licenses",
     dirty_license
     |> replace_common()
     |> String.replace(~r/licenses,\s+/i, "")
    }

  end

  defp extract("Maintaners" <> dirty_maintainers) do
    {"Maintainers",
     dirty_maintainers
     |> replace_common()
     |> String.replace(~r/maintainers,\s+/i, "")
    }
  end

  defp extract("Repo" <> dirty_repo_link) do
    {"Repo",
     dirty_repo_link
     |> String.replace(@cruft_url_pattern, "")
     |> String.replace(@utf_pattern, "")
     |> String.replace(~r/\s+/i, "")
     |> String.replace(~r/links,|GitHub,/i, "")}
  end

  defp extract(line) do
    cond do
      Regex.match?(~r/GitHub/i, line) -> extract("Repo" <> line)
      Regex.match?(~r/maintainers/i, line) -> extract("Maintaners" <> line)
      Regex.match?(~r/licenses/i, line) -> extract("Licenses" <> line)
      true -> ""
    end
  end

  @spec replace_common(String.t()) :: String.t()
  defp replace_common(str) do
    str
    |> String.replace(@cruft_pattern, "")
    |> String.replace(@utf_pattern, "")
    |> String.replace(~r/\s+/, " ")
    |> String.replace(~r/\s+,\s+/, ",")
    |> String.replace(~r/,/, ", ")
  end

  require IEx

  @spec drop_fields(map(), [String.t()]) :: map()
  defp drop_fields(meta_dep_map, fields) do
    Enum.reduce(meta_dep_map, %{}, fn key, acc ->
      k = elem(key, 0)
      Map.put(acc, k, Map.drop(meta_dep_map[k], fields))
    end)
  end
end
