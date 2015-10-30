## This Source Code Form is subject to the terms of the Mozilla Public
## License, v. 2.0. If a copy of the MPL was not distributed with this
## file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Exzmq.Examples.HWclient do

  def main() do
    {:ok, socket} = Exzmq.start([{:type, :req}])
    Exzmq.connect(socket, :tcp, {127,0,0,1}, 5555, [])
    loop(socket, 0)
  end

  def loop(_socket, 10), do: :ok
  def loop(socket, n) do
    :io.format("Sending Hello ~w ...~n",[n])
    Exzmq.send(socket, [<<"Hello",0>>])
    {status, r} = Exzmq.recv(socket)

    if status == :ok do
      :io.format("Received '~s' ~w~n", [r, n])
      loop(socket, n+1)
    else
      IO.puts "error #{r}"
    end
  end

end
