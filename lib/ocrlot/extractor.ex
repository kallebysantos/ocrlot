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
    @enforce_keys [:content]
    defstruct [:content]
  end

  ## Public API
  def start_link(%Args{} = args),
    do: GenServer.start_link(__MODULE__, args)

  ## Callbacks
  @impl true
  def init(%Args{} = args) do
    PubSub.subscribe(Ocrlot.PubSub, args.in)

    process_refs = %{}

    {:ok, {args, process_refs}}
  end

  @impl true
  def handle_info({:process, %Payload{} = payload, metadata}, {%Args{} = args, process_refs}) do
    case WorkerPool.start_child() do
      {:ok, worker} ->
        {:ok, process_id} = Worker.process(worker, payload, self())

        process_refs = Map.put(process_refs, process_id, metadata)

        {:noreply, {args, process_refs}}

      {:error, :max_children} ->
        requeue(payload, metadata)

        {:noreply, {args, process_refs}}
    end
  end

  @impl true
  def handle_info(
        {:extractor_worker_complete, process_id, %Result{} = result},
        {%Args{} = args, process_refs}
      ) do
    {metadata, process_refs} = Map.pop(process_refs, process_id)

    message = args.mapper.({result, metadata})

    PubSub.broadcast(Ocrlot.PubSub, args.out, message)

    {:noreply, {args, process_refs}}
  end

  @impl true
  def handle_info({:requeue, %Payload{} = payload, metadata}, {%Args{} = args, process_refs}) do
    PubSub.local_broadcast(Ocrlot.PubSub, args.in, {:process, payload, metadata})
    {:noreply, {args, process_refs}}
  end

  @impl true
  def handle_info(msg, state) do
    require Logger
    Logger.debug("Unexpected message in #{__MODULE__}: #{inspect(msg)}")

    {:noreply, state}
  end

  defp requeue(%Payload{} = payload, metadata) do
    Process.send_after(self(), {:requeue, payload, metadata}, 3_000)
  end
end
