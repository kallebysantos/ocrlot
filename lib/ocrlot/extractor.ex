defmodule Ocrlot.Extractor do
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

    {:ok, text}
  end
end
