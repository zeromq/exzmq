exzmq - Ã˜MQ in pure Elixir
============================


exzmq implements the Ã˜MQ protocol in 100% pure Elixir.

Motivation
----------

Ã˜MQ is like Erlang message passing for the rest of the world without the
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

* Ã˜MQ compatible
* 100% Elixir
* good fault isolation (a crash in the message decoder won't take down
  your Erlang VM)
* API very similar to other socket interfaces
* runs on non SMP and SMP VM

Contribution process
--------------------

* ZeroMQ [RFC 22 C4.1](http://rfc.zeromq.org/spec:22)

TODO:
-----

* documentation
* push/pull sockets
* identity support
* send queue improvements
* high water marks for send queue

License
-------

The project is released under the MPL 2.0 license
http://mozilla.org/MPL/2.0/.