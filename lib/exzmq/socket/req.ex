## This Source Code Form is subject to the terms of the Mozilla Public
## License, v. 2.0. If a copy of the MPL was not distributed with this
## file, You can obtain one at http://mozilla.org/MPL/2.0/.
 defmodule Exzmq.Socket.Req do

  defstruct last_send: :none

  ###===================================================================

  ###===================================================================
  ### ezmq_socket callbacks
  ###===================================================================

  ##--------------------------------------------------------------------
  ## @private
  ## @doc
  ## Initializes the Fsm
  ##
  ## @spec init(Args) -> {ok, StateName, State} |
  ## {stop, Reason}
  ## @end
  ##--------------------------------------------------------------------

  def init(_opts), do: {:ok, :idle, %Exzmq.Socket.Req{}}

  def close(_state_name, _transport, mqsstate, state) do
    state1 = %{state | last_send: :none}
    {:next_state, :idle, mqsstate, state1}
  end

  def encap_msg({_transport, msg}, _state_name, _mqsstate, _state) do
    Exzmq.simple_encap_msg(msg)
  end

  def decap_msg(_transport, {_remote_id, msg}, _state_name, _mqsstate, _state) do
    Exzmq.simple_decap_msg(msg)
  end

  def idle(:check, {:send, _msg}, %Exzmq.Socket{transports: []}, _state) do
    {:queue, :block}
  end

  def idle(:check, {:send, _msg}, %Exzmq.Socket{transports: [head|_]}, _state) do
    {:ok, head}
  end

  def idle(:check, _, _mqsstate, _state) do
    {:error, :fsm}
  end

  def idle(:do, {:deliver_send, :abort}, mqsstate, state) do
    {:next_state, :idle, mqsstate, state}
  end

  def idle(:do, {:deliver_send, transport}, mqsstate, state) do
    state1 = %{state | last_send: transport}
    mqsstate1 = Exzmq.lb(transport, mqsstate)
    {:next_state, :pending, mqsstate1, state1}
  end

  def idle(:do, :queue_send, mqsstate, state) do
    {:next_state, :send_queued, mqsstate, state}
  end

  def idle(:do, _, _mqsstate, _state) do
    {:error, :fsm}
  end

  def send_queued(:check, {:send, _msg}, %Exzmq.Socket{transports: []}, _state) do
    {:queue, :block}
  end

  def send_queued(:check, :dequeue_send, %Exzmq.Socket{transports: [head|_]}, _state) do
      {:ok, head}
  end

  def send_queued(:check, :dequeue_send, _mqsstate, _state) do
    :keep
  end

  def send_queued(:check, _, _mqsstate, _state) do
    {:error, :fsm}
  end

  def send_queued(:do, {:deliver_send, :abort}, mqsstate, state) do
    {:next_state, :idle, mqsstate, state}
  end

  def send_queued(:do, {:deliver_send, transport}, mqsstate, state) do
    state1 = %{state | last_send: transport}
    mqsstate1 = Exzmq.lb(transport, mqsstate)
    {:next_state, :pending, mqsstate1, state1}
  end

  def send_queued(:do, _, _mqsstate, _state) do
    {:error, :fsm}
  end

  def pending(:check, :recv, _mqsstate, _state), do: :ok

  def pending(:check, {:deliver_recv, transport}, _mqsstate, %Exzmq.Socket.Req{last_send: transport2} )
    when transport == transport2 do
     :ok
  end

  def pending(:check, :deliver, _mqsstate, _state) do
    :ok
  end

  def pending(:check, _, _mqsstate, _state) do
    {:error, :fsm}
  end

  def pending(:do, {:queue, _transport}, mqsstate, state) do
    {:next_state, :reply, mqsstate, state}
  end

  def pending(:do, {:deliver, transport}, mqsstate, state = %Exzmq.Socket.Req{last_send: transport2})
    when transport2 == transport do
    state1 = %{state | last_send: :none}
    {:next_state, :idle, mqsstate, state1}
  end

  def pending(:do, _, _mqsstate, _state) do
    {:error, :fsm}
  end

  def reply(:check, :recv, _mqsstate, _state), do: :ok

  def reply(:check, :deliver, _mqsstate, _state), do: :ok

  def reply(:check, _, _mqsstate, _state), do: {:error, :fsm}

  def reply(:do, {:dequeue, _transport}, mqsstate, state) do
    {:next_state, :reply, mqsstate, state}
  end

  def reply(:do, {:deliver, _transport}, mqsstate, state) do
    state1 = %{state | last_send: :none}
    {:next_state, :idle, mqsstate, state1}
  end

  def reply(:do, _, _mqsstate, _state) do
    {:error, :fsm}
  end

end