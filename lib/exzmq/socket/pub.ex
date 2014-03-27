## This Source Code Form is subject to the terms of the Mozilla Public
## License, v. 2.0. If a copy of the MPL was not distributed with this
## file, You can obtain one at http://mozilla.org/MPL/2.0/.
defmodule Exzmq.Socket.Pub do

	defrecord State do

	end

	##===================================================================
	## API
	##===================================================================

	##===================================================================
	## ezmq_socket callbacks
	##===================================================================

	##--------------------------------------------------------------------
	## @private
	## @doc
	## Initializes the Fsm
	##
	## @spec init(Args) do {ok, stateName, state} |
	## {stop, Reason}
	## @end
	##--------------------------------------------------------------------

    def init(_opts) do
      {:ok, :idle, State.new}
     end

    def close(_state_name, _transport, mqsstate, state) do
      {:next_state, :idle, mqsstate, state}
    end

    def encap_msg({_transport, msg}, _state_name, _mqsstate, _state) do
      Exzmq.simple_encap_msg(msg)
    end

	def decap_msg(_transport, {_remoteId, msg}, _stateName, _mqsstate, _state) do
	  Exzmq.simple_decap_msg(msg)
	end

	def idle(:check, {:send, _msg}, Exzmq.Socket[transports: []], _state) do
	  {:queue, :block}
	end

	def idle(:check, {:send, _msg}, Exzmq.Socket[transports: transports], _state) do
	  {:ok, transports};
	end

	def idle(:check, :dequeue_send, Exzmq.Socket[transports: transports], _state) do
	  {:ok, transports}
	end

	def idle(:check, :dequeue_send, _mqsstate, _state) do
	  :keep
	end

	def idle(:check, _, _mqsstate, _state) do
	  {:error, :fsm}
	end
	
	def idle(:do, :queue_send, mqsstate, state) do
	  {:next_state, :idle, mqsstate, state}
	end

	def idle(:do, {:deliver_send, _transport}, mqsstate, state) do
	  {:next_state, :idle, mqsstate, state}
	end

	def idle(:do, _, _mqsstate, _state) do
	  {:error,:fsm}
	end

end