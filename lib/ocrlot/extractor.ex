defmodule Ocrlot.Extractor do
  use GenServer

  defmodule Payload do
    @enforce_keys :filepath
    defstruct [:filepath, languages: ["eng"]]
  end

  # Client APIs
  def start_link(init_args), do: GenServer.start_link(__MODULE__, init_args)

  def process(pid, params), do: GenServer.call(pid, {:process, params})

  # Callbacks
  @impl true
  def init(init_args), do: {:ok, init_args}

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
