exzmq - ØMQ in pure Elixir
============================


exzmq implements the ØMQ protocol in 100% pure Elixir.

Base on the original work from ezmq(https://github.com/zeromq/ezmq)

Motivation
----------

ØMQ is like Erlang message passing for the rest of the world without the
overhead of a C-Node. So using it to talk to rest of the World seems like
a good idea. Several Erlang wrappers for the C++ reference implemention do
exist. So why reinvent the wheel in Elixir?

Elixir is the way forward for the beam community, it feel like the good time to have
an implementation of zeromq.

Secondly, when using the C++ implementation we
encountered several segfault taking down the entire Erlang VM and most
importantly, the whole concept is so erlangish, that it feels like it has
to be implemented in Elixir itself.

Main features
-------------

* ØMQ compatible : ZMTP 1.0 (http://rfc.zeromq.org/spec:13)
* 100% Elixir
* good fault isolation (a crash in the message decoder won't take down
  your Erlang VM)
* API very similar to other socket interfaces
* runs on non SMP and SMP VM


Examples
--------

```elixir
defmodule Exzmq.Examples.HWserver do

  def main() do
    {:ok, socket} = Exzmq.start([{:type, :rep}])
    Exzmq.bind(socket, :tcp, 5555, [])
    loop(socket)
  end
  
  defp loop(socket) do
    Exzmq.recv(socket)
    :io.format("Received Hello~n")
    Exzmq.send(socket, [<<"World">>])
    loop(socket)
  end
end


defmodule Exzmq.Examples.HWclient do

  def main() do
    {:ok, socket} = Exzmq.start([{:type, :req}])
    Exzmq.connect(socket, :tcp, {127,0,0,1}, 5555, [])
    loop(socket, 0)
  end

  defp loop(_socket, 10), do: :ok

  defp loop(socket, n) do
	 :io.format("Sending Hello ~w ...~n",[n])
	 Exzmq.send(socket, [<<"Hello",0>>])
	 {:ok, r} = Exzmq.recv(socket)
     :io.format("Received '~s' ~w~n", [r, n])
	 loop(socket, n+1)
  end
end	
```

Contribution process
--------------------

* ZeroMQ [RFC 22 C4.1](http://rfc.zeromq.org/spec:22)

TODO:
-----
* ZMTP 2.0
* documentation
* push/pull sockets
* identity support
* send queue improvements
* high water marks for send queue

License
-------

The project is released under the MPL 2.0 license
http://mozilla.org/MPL/2.0/.