defmodule Ocrlot.Extractor.Worker do
  alias Ocrlot.Extractor.Result
  alias Ocrlot.Extractor.Payload
  alias Ocrlot.Extractor

  # Maybe restart :temporary?
  use GenServer, restart: :transient

  # Client APIs
  def start_link(args), do: GenServer.start_link(__MODULE__, args)

  # def try_lock(pid), do: GenServer.call(pid, :try_lock, 10_000)

  def process(pid, %Payload{} = params, receiver) do
    process_id = System.unique_integer()

    GenServer.cast(pid, {:process, process_id, params, receiver})

    {:ok, process_id}
  end

  # Callbacks
  @impl true
  def init(_), do: {:ok, {}}

  @impl true
  def handle_cast(
        {:process, process_id, %Payload{filepath: filepath, languages: langs}, receiver},
        idle_ref
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

    {ocr_output, 0} = System.cmd("tesseract", opts)

    result = %Result{
      content: ocr_output
    }

    send(receiver, {:extractor_worker_complete, process_id, result})

    idle_ref = Process.send_after(self(), :terminate, terminate_worker_after())

    {:noreply, idle_ref}
  end

  # @impl true
  # def handle_call({:process, _}, _, {:waiting, idle_ref}),
  #   do: {:reply, {:error, :not_locked}, {:waiting, idle_ref}}

  # @impl true
  # def handle_call(:try_lock, _, {:waiting, idle_ref}) do
  #   if is_reference(idle_ref) do
  #     Process.cancel_timer(idle_ref)
  #   end

  #   {:reply, :ok, {:lock, idle_ref}}
  # end

  # @impl true
  # def handle_call(:try_lock, _, {:lock, idle_ref}),
  #   do: {:reply, :error, {:lock, idle_ref}}

  @impl true
  def handle_info(:terminate, state) do
    _ = Extractor.WorkerPool.terminate_child(self())
    {:noreply, state}
  end

  # defp terminate_worker_after(), do: Application.fetch_env!(:guava, :terminate_worker_after)
  defp terminate_worker_after(), do: 20_000
end
