## This Source Code Form is subject to the terms of the Mozilla Public
## License, v. 2.0. If a copy of the MPL was not distributed with this
## file, You can obtain one at http://mozilla.org/MPL/2.0/.
defmodule Exzmq.Socket.Rep do

  defstruct last_recv: :none, last_send: :none

  ###===================================================================

  ###===================================================================
  ### ezmq_socket callbacks
  ###===================================================================

  ##--------------------------------------------------------------------
  ## @private
  ## @doc
  ## Initializes the Fsm
  ##
  ## @spec init(Args) -> {ok, stateName, state} |
  ## {stop, Reason}
  ## @end
  ##--------------------------------------------------------------------

  def init(_opts), do: {:ok, :idle, %Exzmq.Socket.Rep{}}

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

  def idle(:check, :recv, _mqsstate, _state), do: :ok

  def idle(:check, {:deliver_recv, _transport}, _mqsstate, _dtate), do: :ok

  def idle(:check, :deliver, _mqsstate, _state), do: :ok

  def idle(:check, _, _mqsstate, _state), do: {:error, :fsm}


  def idle(:do, {:queue, _transport}, mqsstate, state) do
    {:next_state, :pending, mqsstate, state}
  end

  def idle(:do, {:dequeue, _transport}, mqsstate, state) do
    {:next_state, :pending, mqsstate, state}
  end

  def idle(:do, {:deliver, transport}, mqsstate, state) do
    state1 = %{state | last_recv: transport}
    {:next_state, :processing, mqsstate, state1}
  end

  def idle(:do, _, _mqsstate, _state) do
    {:error, :fsm}
  end

  def pending(:check, {:deliver_recv, _transport}, _mqsstate, _state), do: :ok

  def pending(:check, :recv, _mqsstate, _state), do: :ok

  def pending(:check, :deliver, _mqsstate, _state), do: :ok
    
  def pending(:check, _, _mqsstate, _state), do: {:error, :fsm}


  def pending(:do, {:queue, _transport}, mqsstate, state) do
    {:next_state, :pending, mqsstate, state}
  end

  def pending(:do, {:dequeue, _transport}, mqsstate, state) do
    {:next_state, :pending, mqsstate, state}
  end

  def pending(:do, {:deliver, transport}, mqsstate, state) do
    state1 = %{state | last_recv: transport}
    {:next_state, :processing, mqsstate, state1}
  end

  def pending(:do, _, _mqsstate, _state), do: {:error, :fsm}

  def processing(:check, {:deliver_recv, _transport}, _mqsstate, _state), do: :ok

  def processing(:check, {:deliver, _transport}, _mqsstate, _state), do: :queue

  def processing(:check, {:send, _msg}, _mqsstate, %Exzmq.Socket.Rep{last_recv: transport}), do: {:ok, transport}

  def processing(:check, _, _mqsstate, _state), do: {:error, :fsm}

  def processing(:do, {:deliver_send, _transport}, mqsstate, state) do
    state1 = %{state | last_recv: :none}
    {:next_state, :idle, mqsstate, state1}
  end

  def processing(:do, {:queue, _transport}, mqsstate, state) do
    {:next_state, :processing, mqsstate, state}
  end

  def processing(:do, _, _mqsstate, _state) do
    {:error, :fsm}
  end

end