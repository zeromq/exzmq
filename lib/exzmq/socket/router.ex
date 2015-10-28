## This Source Code Form is subject to the terms of the Mozilla Public
## License, v. 2.0. If a copy of the MPL was not distributed with this
## file, You can obtain one at http://mozilla.org/MPL/2.0/.
defmodule Exzmq.Socket.Router do
    
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
      {:ok, :idle, %{}}
     end

    def close(_state_name, _transport, mqsstate, state) do
      {:next_state, :idle, mqsstate, state}
    end

    def encap_msg({_transport, {_identity,msg}}, _state_name, _mqsstate, _state) do
      Exzmq.simple_encap_msg(msg)
    end
  
	def decap_msg(_transport, {remoteId, msg}, _stateName, _mqsstate, _state) do
	  {remoteId, Exzmq.simple_decap_msg(msg)}
	end

	def idle(:check, {:send, _msg}, %Exzmq.Socket{transports: []}, _state) do
	  {:drop, :not_connected}
	end

	def idle(:check, {:send, {identity, _msg}}, mqsstate, _state) do
	    case Exzmq.transports_get(identity, mqsstate) do
	        pid when is_pid(pid) ->
	            {:ok, pid};
	        _ ->
	            {:drop, :invalid_identity}
	    end
	end

	def idle(:check, :deliver, _mqsstate, _state) do
	  :ok
	end

	def idle(:check, {:deliver_recv, _transport}, _mqsstate, _state) do
	  :ok
	end

	def idle(:check, :recv, _mqsstate, _state) do
	  :ok
	end

	def idle(:check, _, _mqsstate, _state) do
	  {:error, :fsm}
	end

	def idle(:do, :queue_send, mqsstate, state) do
	  {:next_state, :idle, mqsstate, state}
	end

    def idle(:do, {:deliver_send, :abort}, mqsstate, state) do
	 {:next_state, :idle, mqsstate, state}
	end

	def idle(:do, {:deliver_send, transport}, mqsstate, state) do
	  mqsstate1 = Exzmq.lb(transport, mqsstate)
	  {:next_state, :idle, mqsstate1, state}
	end

	def idle(:do, {:deliver, _transport}, mqsstate, state) do
	  {:next_state, :idle, mqsstate, state}
	end

	def idle(:do, {:queue, _transport}, mqsstate, state) do
	  {:next_state, :idle, mqsstate, state}
	end

	def idle(:do, {:dequeue, _transport}, mqsstate, state) do
	  {:next_state, :idle, mqsstate, state}
	end

	def idle(:do, _, _mqsstate, _state) do
	  {:error,:fsm}
	end

end