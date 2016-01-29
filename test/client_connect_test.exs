## This Source Code Form is subject to the terms of the Mozilla Public
## License, v. 2.0. If a copy of the MPL was not distributed with this
## file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule ClientConnectTest do

  use ExUnit.Case, async: false

  test "Client should fail to connect" do
  	{:ok, client} = Exzmq.client
  	{:error, :econnrefused} = client |> Exzmq.connect("tcp://127.0.0.1:5555")
  end

  test "Client should connect" do
  	{:ok, server} = Exzmq.server
  	:ok = server |> Exzmq.bind("tcp://127.0.0.1:5555")
  	{:ok, client} = Exzmq.client
  	:ok = client |> Exzmq.connect("tcp://127.0.0.1:5555")
  end

end
