## This Source Code Form is subject to the terms of the Mozilla Public
## License, v. 2.0. If a copy of the MPL was not distributed with this
## file, You can obtain one at http://mozilla.org/MPL/2.0/.
defmodule Exzmq.Supervisor do
  use Supervisor.Behaviour

      
  def start_link() do

    IO.puts "supervisor start_link "
    :supervisor.start_link({:local, __MODULE__}, __MODULE__, [])
  end

  def init([]) do
    children = [
      # Define workers and child supervisors to be supervised
      supervisor(Exzmq.Link.Sup, [], restart: :permanent)
    ]

    # See http://elixir-lang.org/docs/stable/Supervisor.Behaviour.html
    # for other strategies and supported options
    supervise(children, [strategy: :one_for_one, max_restarts: 5, max_seconds: 10])
  end
end
