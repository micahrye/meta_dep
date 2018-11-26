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

  NOTE: Parses hex_metadataa.config to obtain meta information

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
  {"bunt", %{"Licenses" => "MIT"}}

  $ mix meta_dep -p ./deps -vd bunt
  {"bunt",
    %{
      "Licenses" => "MIT",
      "Maintainers" => "René Föhring",
      "Repo" => "https://github.com/rrrene/bunt"
    }}

  $ mix meta_dep -l
    {"bunt", %{"Licenses" => "MIT"}}
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
  require Logger

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
    meta_dep = extract_meta_data(path, dep)

    cond do
      verbose == true -> meta_dep
      licences == true -> drop_fields(meta_dep, ["Maintainers", "Repo"])
      true -> meta_dep
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

  @doc """
  `extract_meta_data/2` parses the file `hex_metadataa.config` to extract
  meta data for dependencies.
  """
  @spec extract_meta_data(String.t(), String.t()) :: map()
  def extract_meta_data(path, dep \\ "*") do
    IO.puts("Path.wildcard(path <> dep) = #{Path.wildcard(path <> dep)}")

    Path.wildcard(path <> dep)
    |> Enum.map(fn dep ->
      dep_name = String.replace(dep, @leading_path, "")
      content =
        case File.read(dep <> "/hex_metadata.config") do
          {:ok, content} ->
            content

          {:error, reason} ->
            Logger.error("Error getting meta data for #{dep_name}. Reason #{inspect reason}")
            ""
        end

      String.replace(content, "\n", "")
      |> String.split(@end_of_term)
      |> Enum.map(fn line -> {dep_name, extract(line)} end)
      |> Enum.filter(fn x -> if elem(x, 1) == "", do: false, else: elem(x, 1) end)
    end)
    |> Enum.flat_map(& &1)
    |> Enum.reduce(
      %{},
      fn dep, acc ->
        update_meta_dep(acc, dep)
      end
    )
  end

  @doc """
  `extract_meta_data/0` call  `extract_meta_data/2` with default values
  """
  @spec extract_meta_data() :: map()
  def extract_meta_data() do
    extract_meta_data("./deps/", "*")
  end

  @doc """
  `update_meta_dep/2` expects a map representing the meta information for
  dependencies and a tulip object resulting from parsing meta file. The
  map is updated with information from tulple and returned.
  """
  @spec update_meta_dep(map(), tuple()) :: map()
  def update_meta_dep(m, dep) do
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

  @doc """
  `print_to_console/1` prints the map representing the meta information for
  dependencies.
  """
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
     |> String.replace(~r/licenses,\s+/i, "")}
  end

  defp extract("Version" <> dirty_version) do
    {"Version",
    dirty_version
    |> replace_common()
    |> String.replace(~r/version,\s+/i, "")}
  end

  defp extract("Maintaners" <> dirty_maintainers) do
    {"Maintainers",
     dirty_maintainers
     |> replace_common()
     |> String.replace(~r/maintainers,\s+/i, "")}
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
      Regex.match?(~r/github/i, line) -> extract("Repo" <> line)
      Regex.match?(~r/maintainers/i, line) -> extract("Maintaners" <> line)
      Regex.match?(~r/licenses/i, line) -> extract("Licenses" <> line)
      Regex.match?(~r/version/i, line) -> extract("Version" <> line)
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
  defp drop_fields(meta_dep, fields) do
    Enum.reduce(meta_dep, %{}, fn key, acc ->
      k = elem(key, 0)
      Map.put(acc, k, Map.drop(meta_dep[k], fields))
    end)
  end
end
