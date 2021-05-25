defmodule Frequency do
  use DynamicSupervisor

  def start_link(_) do
    DynamicSupervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Count letter frequency in parallel.

  Returns a map of characters to frequencies.

  The number of worker processes to use can be set with 'workers'.
  """
  @spec frequency([String.t()], pos_integer) :: map
  def frequency(texts, workers) when is_integer(workers) do
    start_worker(self(), texts, workers)

    receive do
      {:freq, freq} ->
        freq
    end
  end

  defp start_worker(caller, texts, workers) do
    child_spec = %{
      id: "FREQ_WORKER_#{System.unique_integer()}",
      start: {
        Frequency.Worker,
        :start_link,
        [[caller: caller, texts: texts, workers: workers]]
      },
      restart: :transient
    }

    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end
end
