## This Source Code Form is subject to the terms of the Mozilla Public
## License, v. 2.0. If a copy of the MPL was not distributed with this
## file, You can obtain one at http://mozilla.org/MPL/2.0/.
defmodule Exzmq.Examples.HWserver do

  def main() do
   
    port = 5555
	
    {:ok, socket} = Exzmq.start([{:type, :rep}])
    Exzmq.bind(socket, :tcp, port, [])
    loop(socket)
  end
  
  def loop(socket) do
    Exzmq.recv(socket)
    :io.format("Received Hello~n")
    Exzmq.send(socket, [<<"World">>])
    loop(socket)
  end

end