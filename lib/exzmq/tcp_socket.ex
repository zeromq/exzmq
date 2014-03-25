## This Source Code Form is subject to the terms of the Mozilla Public
## License, v. 2.0. If a copy of the MPL was not distributed with this
## file, You can obtain one at http://mozilla.org/MPL/2.0/.
defmodule Exzmq.Tcp.Socket do

@behaviour :gen_listener_tcp

@tcp_port 5555
@tcp_opts [:binary, :inet,
			{:ip, {127,0,0,1}},
			{:active, false},
			{:sent_timeout, 5000},
			{:backlog, 10},
			{:nodelay, true},
			{:packet, :raw},
			{:reuseaddr, true}]

#todo todo ifdef			
@server_opts {}

	##===================================================================
	## External functions
	##===================================================================

	## @doc Start the server.
	def start(identity, port, opts) do
	    :gen_listener_tcp.start(__MODULE__, [self(), identity, port, opts], [@server_opts])
	end

	def start_link(identity, port, opts) do
	    :gen_listener_tcp.start_link(__MODULE__, [self(), identity, port, opts], [@server_opts])
	end

	def init([mqsocket, identity, port, opts]) do
	    {:ok, {port, opts}, {mqsocket, identity}}
	end

	def handle_accept(sock, state = {mqsocket, identity}) do

	    case Exzmq.Link.start_connection() do
	        {:ok, pid} ->
	            Exzmq.Link.accept(mqsocket, identity, pid, sock)
	        _ ->
	            :error_logger.error_report([{:event, :accept_failed}])
	            :gen_tcp.close(Sock)
	    end
	    {:noreply, state}
	 end

	def handle_call(request, _from, state) do
	  {:reply, {:illegal_request, request}, state}
	end

	def handle_cast(_request, state) do
	  {:noreply, state}
	end

	def handle_info(_info, state) do
	  {:noreply, state}
	end

	def terminate(_reason, _state) do
	    #?DEBUG("ezmq_tcp_socket terminate on ~p", [_Reason]),
	    :ok
	end

	def code_change(_old_vsn, state, _extra) do
	    {:ok, state}
	end
end