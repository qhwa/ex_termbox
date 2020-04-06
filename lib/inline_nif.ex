defmodule InlineNif do
  @moduledoc """
  An module to make NIF with Elixir escript easier
  """
  @fallback_tmp_dir "./tmp"

  defmacro __using__(nifs) do
    quote location: :keep do
      @nif_contents InlineNif.inline(unquote(nifs))

      alias InlineNif.NifUndefError

      def nif_path(nif) do
        case nif_content(nif) do
          %NifUndefError{} = err ->
            err

          content when is_binary(content) ->
            InlineNif.gen_nif_path(
              nif,
              content
            )
        end
      end

      def nif_content(nif) do
        Keyword.get(@nif_contents, nif, NifUndefError.exception(nif))
      end
    end
  end

  @doc """
  Inject NIF file contents to module attributes
  """
  def inline(nifs) do
    for {name, path} <- nifs do
      {name, path |> read()}
    end
  end

  defp read(path), do: path |> to_file_path() |> File.read!()
  defp to_file_path(path), do: path <> ext(:os.type())
  defp ext(:windows), do: ".dll"
  defp ext(_), do: ".so"

  @doc """
  Generate a file based on NIF name and its content.
  """
  def gen_nif_path(name, content) do
    path = Path.join(tmp_dir(), filename(name, content))
    path |> to_file_path() |> maybe_make_temp_file(content)
    path
  end

  defp tmp_dir, do: System.tmp_dir() || @fallback_tmp_dir

  defp filename(name, content) do
    digest =
      :crypto.hash(:md5, content)
      |> Base.encode16()
      |> String.downcase()

    IO.iodata_to_binary([to_string(name), "_", digest])
  end

  defp maybe_make_temp_file(path, content) do
    unless File.exists?(path) do
      :ok = path |> Path.dirname() |> File.mkdir_p()
      File.write!(path, content, [:binary])
    end
  end

  defmodule NifUndefError do
    defexception [:message]

    @impl true
    def exception(nif) do
      %__MODULE__{message: "NIF #{nif} is not defined."}
    end
  end
end
