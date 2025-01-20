defmodule Ocrlot.Extractor.Worker do
  alias Ocrlot.Extractor.Payload
  alias Ocrlot.Extractor

  # Maybe restart :temporary?
  use GenServer, restart: :transient

  # Client APIs
  def start_link(args), do: GenServer.start_link(__MODULE__, args)

  def try_lock(pid), do: GenServer.call(pid, :try_lock, 10_000)

  def process(pid, %Payload{} = params), do: GenServer.call(pid, {:process, params}, 10_000)

  # Callbacks
  @impl true
  def init(state), do: {:ok, {state, nil}}

  @impl true
  def handle_call(
        {:process, %Payload{filepath: filepath, languages: langs}},
        _,
        {:lock, idle_ref}
      ) do
    if is_reference(idle_ref) do
      Process.cancel_timer(idle_ref)
    end

    opts = [
      filepath,
      "-",
      "-l",
      Enum.join(langs, "+"),
      "quiet",
      "-psm",
      "6"
    ]

    {result, 0} = System.cmd("tesseract", opts)

    idle_ref = Process.send_after(self(), :terminate, terminate_worker_after())
    {:reply, {:ok, result}, {:waiting, idle_ref}}
  end

  @impl true
  def handle_call({:process, _}, _, {:waiting, idle_ref}),
    do: {:reply, {:error, :not_locked}, {:waiting, idle_ref}}

  @impl true
  def handle_call(:try_lock, _, {:waiting, idle_ref}) do
    if is_reference(idle_ref) do
      Process.cancel_timer(idle_ref)
    end

    {:reply, :ok, {:lock, idle_ref}}
  end

  @impl true
  def handle_call(:try_lock, _, {:lock, idle_ref}),
    do: {:reply, :error, {:lock, idle_ref}}

  @impl true
  def handle_info(:terminate, state) do
    _ = Extractor.WorkerPool.terminate_child(self())
    {:noreply, state}
  end

  # defp terminate_worker_after(), do: Application.fetch_env!(:guava, :terminate_worker_after)
  defp terminate_worker_after(), do: 20_000
end
