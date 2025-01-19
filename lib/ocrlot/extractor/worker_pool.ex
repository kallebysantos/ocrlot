defmodule Ocrlot.Extractor.WorkerPool do
  alias Ocrlot.Extractor.Worker
  use DynamicSupervisor

  # Client APIs
  def start_link(args \\ []) do
    # round robin counter
    {:ok, _} = Agent.start_link(fn -> 0 end, name: Ocrlot.Extractor.WorkerPoolState)
    DynamicSupervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def terminate_child(pid), do: DynamicSupervisor.terminate_child(__MODULE__, pid)

  # Callbacks
  @impl true
  def init(_args),
    do: DynamicSupervisor.init(strategy: :one_for_one, max_children: max_children())

  # def start_child, do: DynamicSupervisor.start_child(__MODULE__, {Worker, [:lock]})

  # def get_child, do: round_robin(max_retries())

  def start_child do
    case DynamicSupervisor.start_child(__MODULE__, {Worker, :lock}) do
      {:ok, pid} -> {:ok, pid}
      {:error, :max_children} -> round_robin(max_children())
      error -> error
    end
  end

  defp round_robin(retries) when retries > 0 do
    case DynamicSupervisor.which_children(__MODULE__) do
      [] ->
        {:error, :no_workers_available}

      workers ->
        counter =
          Agent.get_and_update(Ocrlot.Extractor.WorkerPoolState, fn counter ->
            {counter, counter + 1}
          end)

        case Enum.at(workers, rem(counter, length(workers))) do
          {:undefined, pid, _, _} ->
            case Worker.try_lock(pid) do
              :ok -> {:ok, pid}
              _ -> round_robin(retries - 1)
            end

          _ ->
            round_robin(retries - 1)
        end
    end
  end

  defp round_robin(0), do: {:error, :no_workers_available}

  # defp max_children(), do: Application.fetch_env!(:guava, :concurent_task_limit)
  def max_children(), do: 10
  # defp max_retries(), do: 3
end
