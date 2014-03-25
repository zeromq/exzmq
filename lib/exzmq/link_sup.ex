## This Source Code Form is subject to the terms of the Mozilla Public
## License, v. 2.0. If a copy of the MPL was not distributed with this
## file, You can obtain one at http://mozilla.org/MPL/2.0/.
defmodule Exzmq.Link.Sup do
  use Supervisor.Behaviour

  def start_link do

    :supervisor.start_link({:local, __MODULE__}, __MODULE__, [])
  end

  def start_connection() do
    :supervisor.start_child(__MODULE__, [])
  end

  def datapaths() do
    :lists.map(fn({_, child, _, _}) -> child end, :supervisor.which_children(__MODULE__))
  end

  def init([]) do
    children = [
      # Define workers and child supervisors to be supervised
      worker(Exzmq.Link, [], [restart: :temporary, shutdown: :brutal_kill])
    ]

    # See http://elixir-lang.org/docs/stable/Supervisor.Behaviour.html
    # for other strategies and supported options
    supervise(children, [strategy: :simple_one_for_one, max_restarts: 0, max_seconds: 1])
  end
end
