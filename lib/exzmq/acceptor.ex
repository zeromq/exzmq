## This Source Code Form is subject to the terms of the Mozilla Public
## License, v. 2.0. If a copy of the MPL was not distributed with this
## file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Exzmq.Acceptor do
	
  @moduledoc """
  This GenServer waits for incoming connections.
  Once a new connection is accepted, it is passed over to the parent SERVER socket.
  """

  use GenServer

  def init(state) do
  	IO.puts "Acceptor started"
  	GenServer.cast(self, :accept)
    {:ok, state}
  end

  def handle_cast(:accept, state) do
  	IO.puts "Waiting for connection: #{inspect state}"
    case :gen_tcp.accept(state.socket) do
      {:ok, client} ->
        IO.puts "Accepted: #{inspect client}"
        :ok = :gen_tcp.controlling_process(client, state.parent)
        state.parent |> GenServer.cast({:new_client, client})
      error ->
        IO.puts "Not accepted: #{inspect error}"
    end
  	GenServer.cast(self, :accept)
  	{:noreply, state}
  end

end