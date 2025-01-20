defmodule Ocrlot.Extractor do
  alias Phoenix.PubSub
  alias Ocrlot.Extractor.Worker
  alias Ocrlot.Extractor.WorkerPool
  alias Ocrlot.Extractor.Worker.Payload

  use GenServer

  defmodule Args do
    @enforce_keys [:in, :out]
    defstruct [:in, :out, mapper: &__MODULE__.keep/1]
    def keep(value), do: value
  end

  defmodule Payload do
    @enforce_keys :filepath
    defstruct [:filepath, languages: ["eng"]]
  end

  defmodule Result do
    @enforce_keys [:filepath, :content]
    defstruct [:filepath, :content]
  end

  ## Public API
  def start_link(%Args{} = args),
    do: GenServer.start_link(__MODULE__, args)

  ## Callbacks
  @impl true
  def init(%Args{} = args) do
    PubSub.subscribe(Ocrlot.PubSub, args.in)

    {:ok, args}
  end

  @impl true
  def handle_info({:process, %Payload{} = payload, metadata}, %Args{} = state) do
    case WorkerPool.start_child() do
      {:ok, worker} ->
        Task.Supervisor.start_child(Ocrlot.Converter.TaskSupervisor, fn ->
          {:ok, content} = Worker.process(worker, payload)

          result = %Result{
            filepath: payload.filepath,
            content: content
          }

          message = state.mapper.({result, metadata})

          PubSub.broadcast(Ocrlot.PubSub, state.out, message)
        end)

      {:error, :max_children} ->
        requeue(payload)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:requeue, %Payload{} = payload}, state) do
    PubSub.local_broadcast(Ocrlot.PubSub, state.in, {:process, payload})
    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    require Logger
    Logger.debug("Unexpected message in #{__MODULE__}: #{inspect(msg)}")

    {:noreply, state}
  end

  defp requeue(%Payload{} = payload) do
    Process.send_after(self(), {:requeue, payload}, 3_000)
  end
end
