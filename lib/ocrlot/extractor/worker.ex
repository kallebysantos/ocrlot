defmodule Ocrlot.Extractor.Worker do
  alias Ocrlot.Extractor
  # Maybe restart :temporary?
  use GenServer, restart: :transient

  defmodule(Payload) do
    @enforce_keys :filepath
    defstruct [:filepath, languages: ["eng"]]
  end

  # Client APIs
  def start_link(args), do: GenServer.start_link(__MODULE__, args)

  def process(pid, %Payload{} = params), do: GenServer.call(pid, {:process, params}, 30_000)

  # Callbacks
  @impl true
  def init(args), do: {:ok, args}

  @impl true
  def handle_call({:process, %Payload{} = params}, _from, state) do
    result = img_to_text(params)

    {:reply, result, state}
  end

  @impl true
  def handle_info(:terminate, state) do
    _ = Extractor.WorkerPool.terminate_child(self())
    {:noreply, state}
  end

  def img_to_text(%Payload{filepath: filepath, languages: langs}) do
    opts = [
      filepath,
      "-",
      "-l",
      Enum.join(langs, "+"),
      "quiet",
      "-psm",
      "6"
    ]

    {text, 0} = System.cmd("tesseract", opts)

    Process.send_after(self(), :terminate, terminate_worker_after())

    {:ok, text}
  end

  # defp terminate_worker_after(), do: Application.fetch_env!(:guava, :terminate_worker_after)
  defp terminate_worker_after(), do: 500
end
