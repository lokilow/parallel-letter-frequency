defmodule Frequency do
  @doc """
  Count letter frequency in parallel.

  Returns a map of characters to frequencies.

  The number of worker processes to use can be set with 'workers'.
  """
  @spec frequency([String.t()], pos_integer) :: map
  def frequency([], _workers), do: %{}

  def frequency(texts, workers) when is_integer(workers) do
    {:ok, remaining_texts, free_workers} = initialize_work(texts, workers)
    loop(remaining_texts, free_workers, workers, %{})
  end

  defp loop(remaining_texts, free_workers, total_workers, total_freq) do
    receive do
      {:freq, text_freq} ->
        total_freq = merge_freq(total_freq, text_freq)

        case remaining_texts do
          [] ->
            free_workers = free_workers + 1

            if free_workers == total_workers do
              total_freq
            else
              loop(remaining_texts, free_workers, total_workers, total_freq)
            end

          [t | ts] ->
            _pid = spawn_work(t, self())
            loop(ts, free_workers, total_workers, total_freq)
        end
    end
  end

  defp initialize_work([] = remaining_texts, free_workers),
    do: {:ok, remaining_texts, free_workers}

  defp initialize_work(remaining_texts, 0 = free_workers),
    do: {:ok, remaining_texts, free_workers}

  defp initialize_work([text | ts], free_workers) do
    _pid = spawn_work(text, self())

    initialize_work(ts, free_workers - 1)
  end

  defp spawn_work(text, caller) do
    _pid =
      Process.spawn(
        fn ->
          text_freq = string_freq(text)
          :ok = Process.send(caller, {:freq, text_freq}, [])
        end,
        []
      )
  end

  defp merge_freq(f1, f2), do: Map.merge(f1, f2, fn _k, v1, v2 -> v1 + v2 end)

  #### Original Solutions
  # Uses arguably the best (simplest) solution for this specific problem
  # although the exact number of workers is not guaranteed to be the one the function is called with.
  def frequency1(texts, workers) when is_integer(workers) do
    Task.async_stream(texts, &string_freq/1, max_concurrency: workers)
    |> Enum.reduce(%{}, fn {:ok, freqs}, acc ->
      Map.merge(freqs, acc, fn _k, v1, v2 -> v1 + v2 end)
    end)
  end

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
