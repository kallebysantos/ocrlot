defmodule Ocrlot.Converter do
  alias Phoenix.PubSub

  use GenServer

  defmodule Args do
    @enforce_keys [:in, :out]
    defstruct [:in, :out, mapper: &__MODULE__.keep/1]
    def keep(value), do: value
  end

  defmodule Payload do
    defstruct [:filepath, :output_folder]
  end

  defmodule Result do
    @enforce_keys [:original_filepath, :page_number, :filepath]
    defstruct [:original_filepath, :page_number, :filepath]
  end

  ## Public API
  def start_link(%Args{} = args),
    do: GenServer.start_link(__MODULE__, args)

  def get_file_info(filepath) do
    {result_str, 0} =
      System.cmd("pdfinfo", [
        filepath
      ])

    [_, total_pages] = Regex.run(~r/Pages:\s+(\d+)/, result_str)

    info = %{
      original_filepath: filepath,
      total_pages: String.to_integer(total_pages)
    }

    {:ok, info}
  end

  ## Callbacks
  @impl true
  def init(%Args{} = args) do
    PubSub.subscribe(Ocrlot.PubSub, args.in)

    {:ok, args}
  end

  @impl true
  def handle_info({:process, %Payload{} = payload, metadata}, %Args{} = state) do
    if !File.dir?(payload.output_folder) do
      File.mkdir!(payload.output_folder)
    end

    {:ok, file_info} = get_file_info(payload.filepath)

    output_path_prefix = Path.join(payload.output_folder, "page")

    opts = [
      "-r",
      "300",
      "-jpeg",
      "-jpegopt",
      "quality=100",
      payload.filepath,
      output_path_prefix
    ]

    {_, 0} = System.cmd("pdftoppm", opts)

    1..file_info.total_pages
    |> Stream.map(fn page_idx ->
      leading_count =
        file_info.total_pages
        |> Integer.digits()
        |> length()

      page_idx_str =
        page_idx
        |> Integer.to_string()
        |> String.pad_leading(leading_count, "0")

      page_path = "#{output_path_prefix}-#{page_idx_str}.jpg"

      result = %Result{
        original_filepath: payload.filepath,
        page_number: page_idx,
        filepath: page_path
      }

      {result, metadata}
    end)
    |> Stream.map(state.mapper)
    |> Enum.each(fn message -> PubSub.broadcast(Ocrlot.PubSub, state.out, message) end)

    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    require Logger
    Logger.debug("Unexpected message in #{__MODULE__}: #{inspect(msg)}")

    {:noreply, state}
  end
end
