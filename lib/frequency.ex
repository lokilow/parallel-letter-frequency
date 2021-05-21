defmodule Frequency do
  @doc """
  Count letter frequency in parallel.

  Returns a map of characters to frequencies.

  The number of worker processes to use can be set with 'workers'.
  """
  @spec frequency([String.t()], pos_integer) :: map
  def frequency(texts, workers) when is_integer(workers) do
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
