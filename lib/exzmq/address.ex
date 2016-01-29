## This Source Code Form is subject to the terms of the Mozilla Public
## License, v. 2.0. If a copy of the MPL was not distributed with this
## file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Exzmq.Address do

  # transport: currently, only :tcp is supported
  # ip: an IP address as Erlang tuple
  # port: the port number
  defstruct transport: :tcp, ip: nil, port: nil

  def parse(%Exzmq.Address{} = address) do
  	address
  end
  def parse(address) do
  	unless address |> String.starts_with?("tcp://") do
  	  raise "Unsupported transport: #{address}"
  	end
  	[ip, port] = address
  	|> String.slice(6,999)
  	|> String.split(":")
  	{:ok, ip} = ip |> String.to_char_list |> :inet.parse_address
  	%Exzmq.Address{ip: ip, port: port |> String.to_integer}
  end

end
