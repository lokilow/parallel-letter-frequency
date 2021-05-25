defmodule Frequency.Worker do
  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl true
  def init(caller: caller, texts: texts, workers: workers) do
    state = %{caller: caller, texts: texts, outstanding_workers: workers, freq: %{}}

    1..workers
    |> Enum.each(fn _ ->
      spawn_worker(self())
    end)

    {:ok, state}
  end

  @impl true
  def handle_call({:next_text, prev_freq}, _from, state) do
    state = %{state | freq: merge_freq(state.freq, prev_freq)}

    case state.texts do
      [t | ts] ->
        {:reply, t, %{state | texts: ts}}

      [] ->
        outstanding_workers = state.outstanding_workers - 1

        if outstanding_workers == 0 do
          {:stop, :normal, [], state}
        else
          {:reply, [], %{state | outstanding_workers: outstanding_workers}}
        end
    end
  end

  @impl true
  def terminate(:normal, %{caller: caller, freq: freq}) do
    :ok = Process.send(caller, {:freq, freq}, [])
  end

  defp spawn_worker(server) do
    spawn_link(fn ->
      text = GenServer.call(server, {:next_text, %{}})
      loop(server, text)
    end)
  end

  defp loop(_server, []), do: :ok

  defp loop(server, text) when is_binary(text) do
    freq = string_freq(text)
    text = GenServer.call(server, {:next_text, freq})
    loop(server, text)
  end

  defp merge_freq(f1, f2), do: Map.merge(f1, f2, fn _k, v1, v2 -> v1 + v2 end)

  @invalid_characters ~r/[ 0-9\.\?\-\(\)\[\]\{\}\|,.'":;!@#%&*_=]+/
  # character frequencies of a single string
  defp string_freq(text) when is_binary(text) do
    # clean text
    text = String.replace(text, @invalid_characters, "")
    string_freq(text, %{})
  end

  defp string_freq(s, acc) do
    case String.next_grapheme(s) do
      nil ->
        acc

      {char, rest} ->
        char = String.downcase(char)
        string_freq(rest, acc |> Map.update(char, 1, &(&1 + 1)))
    end
  end
end
