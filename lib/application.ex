defmodule Frequency.Application do
  use Application

  def start(_type, _args) do
    children = [
      Frequency
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
