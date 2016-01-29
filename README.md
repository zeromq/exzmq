# exzmq

ZeroMQ 3.1 for Elixir

[![Build Status](https://travis-ci.org/zeromq/exzmq.svg?branch=master)](https://travis-ci.org/zeromq/exzmq)

## Status

* This project is a work in progress.
* It is not ready for production use yet.
* Contributions are welcome

## Examples

```elixir
defmodule ServerExample do

  def main do
    {:ok, socket} = Exzmq.server("tcp://127.0.0.1:5555")
    socket |> receive
  end
  
  defp receive(socket) do
    message = socket |> Exzmq.recv
    IO.puts "Received: #{inspect message}"
    socket |> receive
  end

end

defmodule ClientExample do

  def main do
    {:ok, socket} = Exzmq.client("tcp://127.0.0.1:5555")
    socket |> Exzmq.send("Hello")
  end

end	
```

## Contribution

This projects uses the [C4.1 process](http://rfc.zeromq.org/spec:22).

## License

The project is released under the MPL 2.0 license
http://mozilla.org/MPL/2.0/.
