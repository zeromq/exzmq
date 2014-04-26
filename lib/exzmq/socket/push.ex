## This Source Code Form is subject to the terms of the Mozilla Public
## License, v. 2.0. If a copy of the MPL was not distributed with this
## file, You can obtain one at http://mozilla.org/MPL/2.0/.
defmodule Exzmq.Socket.Push do

	defrecord State do

	end

	##===================================================================
	## API
	##===================================================================

	##===================================================================
	## ezmq_socket callbacks
	##===================================================================
	@type state_name :: atom
	@type reason :: atom
  @spec init(tuple) :: {:ok, state_name, State.t} | {:stop, reason}
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

	def idle(:check, {:send, _msg}, Exzmq.Socket[transports: [head|_]], _state) do
	  {:ok, head};
	end

	def idle(:check, :dequeue_send, Exzmq.Socket[transports: [head|_]], _state) do
	  {:ok, head}
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
	
	def idle(:do, {:deliver_send, transport}, mqsstate, state) do
	  mqsstate1 = Exzmq.lb(transport, mqsstate)
	  {:next_state, :idle, mqsstate1, state}
	end

	def idle(:do, _, _mqsstate, _state) do
	  {:error,:fsm}
	end

end