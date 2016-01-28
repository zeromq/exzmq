## This Source Code Form is subject to the terms of the Mozilla Public
## License, v. 2.0. If a copy of the MPL was not distributed with this
## file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Exzmq.Link do
  @behaviour :gen_fsm

  @fsm_opts {}
  @startup_timeout 10_000
  @connect_timeout 10_000
  @request_timeout 10_000
  @tcp_opts [:binary, :inet6,
             {:active, false},
             {:send_timeout, 5000},
             {:backlog, 100},
             {:nodelay, true},
             {:packet, :raw},
             {:reuseaddr, true}]

  alias Exzmq.Frame
  alias Exzmq.Link.State
  alias Exzmq.Link.Sup

  def start_link do
    :gen_fsm.start_link(__MODULE__, [], [@fsm_opts])
  end

  def start_connection do
    Sup.start_connection()
  end

  def accept(mqsocket, identity, server, socket) do
    :ok = :gen_tcp.controlling_process(socket, server)
    :gen_fsm.send_event(server, {:accept, mqsocket, identity, socket})
  end

  def connect(identity, server, :tcp, address, port, tcp_opts, timeout) do
    :gen_fsm.send_event(server, {:connect, self(), identity, :tcp, address, port, tcp_opts, timeout})
  end

  def send(server, msg) do
    :gen_fsm.send_event(server, {:send, msg})
  end

  def close(server) do
    :gen_fsm.sync_send_all_state_event(server, :close)
  end

  def init([]) do
    Process.flag(:trap_exit, true)
    {:ok, :setup, %State{}, @startup_timeout}
  end

  def setup({:accept, mqsocket, identity, socket}, state) do
    newstate = %{state | mqsocket: mqsocket, identity: identity, socket: socket}
    packet = Frame.encode_greeting(state.version, nil, identity)
    send_packet(packet, {:next_state, :open, newstate, @connect_timeout})
  end
  def setup({:connect, mqsocket, identity, :tcp, address, port, tcpopts, timeout}, state) do
    case :gen_tcp.connect(address, port, tcpopts, timeout) do
      {:ok, socket} ->
        newstate = %{state | mqsocket: mqsocket, identity: identity, socket: socket}
        :ok = :inet.setopts(socket, [{:active,:once}])
        {:next_state, :connecting, newstate, @connect_timeout}
      reply ->
        Exzmq.deliver_connect(mqsocket, reply)
        {:stop, :normal, state}
    end
  end

  def connecting(:timeout, %State{mqsocket: mqsocket} = state) do
    Exzmq.deliver_connect(mqsocket, {:error, :timeout})
    {:stop, :normal, state}
  end
  def connecting({:greeting, ver, _socket_type, remote_id0}, %State{mqsocket: mqsocket, identity: identity} = state) do
    remoteid = Exzmq.remote_id_assign(remote_id0)
    Exzmq.deliver_connect(mqsocket, {:ok, remoteid})
    packet = Frame.encode_greeting(state.version, :undefined, identity)
    send_packet(packet, {:next_state, :connected, %{state | remote_id: remoteid, version: ver}})
  end
  def connecting(_msg, %State{mqsocket: mqsocket} = state) do
    Exzmq.deliver_connect(mqsocket, {:error, :data})
    {:stop, :normal, state}
  end

  def open(:timeout, state) do
    {:stop, :normal, state}
  end
  def open({:greeting, ver, _socket_type, remote_id0}, %State{mqsocket: mqsocket} = state) do
    remoteid = Exzmq.remote_id_assign(remote_id0)
    Exzmq.deliver_accept(mqsocket, remoteid)
    {:next_state, :connected, %{state | remote_id: remoteid, version: ver}}
  end
  def open(_msg, state) do
    {:stop, :normal, state}
  end

  def connected(:timeout, state) do
    {:stop, :normal, state}
  end
  def connected({:in, [_head | frames]}, %State{mqsocket: mqsocket, remote_id: remoteid} = state) do
    Exzmq.deliver_recv(mqsocket, {remoteid, frames})
    {:next_state, :connected, state}
  end
  def connected({:send, msg}, state) do
    send_frames(["" | msg], {:next_state, :connected, state})
  end

  def handle_event(_event, state_name, state) do
    {:next_state, state_name, state}
  end

  def handle_sync_event(:close, _from, _state_name, state) do
    {:stop, :normal, :ok, state}
  end
  def handle_sync_event(_event, _from, state_name, state) do
    reply = :ok
    {:reply, reply, state_name, state}
  end

  def handle_info({:'EXIT', mqsocket, _reason}, _state_name, %State{mqsocket: mqsocket} = state) do
    {:stop, :normal, %{state | mqsocket: nil}}
  end
  def handle_info({:tcp, socket, data}, state_name, %State{socket: socket} = state) do
    state1 = %{state | pending: state.pending <> data}
    handle_data(state_name, state1, {:next_state, state_name, state1})
  end
  def handle_info({:tcp_closed, socket}, _state_name, %State{socket: socket} = state) do
    #?DEBUG("client disconnected: ~w~n", [Socket]),
    {:stop, :normal, state}
  end

  def handle_data(_state_name, %State{socket: socket, pending: <<>>}, process_state_next) do
    :ok = :inet.setopts(socket, [{:active, :once}])
    process_state_next
  end
  def handle_data(state_name, %State{socket: socket, pending: pending} = state, process_state_next)
    when state_name === :connecting or state_name === :open do
    {msg, data_rest} = Frame.decode_greeting(pending)
    state1 = %{state | pending: data_rest}
    case msg do
      :more ->
        :ok = :inet.setopts(socket,[{:active, :once}])
        put_elem(process_state_next, 2, state1)
      :invalid ->
        fake_msg ={:greeting, {1,0}, nil, ""}
        reply = apply(__MODULE__, state_name,[fake_msg, state1])
        handle_data_reply(reply)
      {:greeting, _ver, _socket_type, _identity} ->
        reply = apply(__MODULE__, state_name, [msg, state1])
        handle_data_reply(reply)
    end
  end
  def handle_data(state_name, %State{socket: socket, version: ver, pending: pending} = state,
                   process_state_next) do
    {msg, data_rest} = Frame.decode(ver, pending)
    state1 = %{state | pending: data_rest}
    case msg do
      :more ->
        :ok = :inet.setopts(socket,[{:active, :once}])
        put_elem(process_state_next, 2, state1)
      :invalid ->
        {:stop, :normal, state1}
      {true, frame} ->
        state2 = %{state1 | frames: [frame|state1.frames]}
        handle_data(state_name, state2, put_elem(process_state_next, 2, state2))
      {false, frame} ->
        frames = Enum.reverse([frame|state1.frames])
        state2 = %{state1 | frames: []}
        reply = exec_sync(frames, state_name, state2)
        handle_data_reply(reply)
    end
  end

  def terminate(_reason, _state_name, %State{mqsocket: mqsocket, socket: socket})  when is_port(socket)  do
    Exzmq.deliver_close(mqsocket)
    :gen_tcp.close(socket)
    :ok
  end
  def terminate(_reason, _state_name, %State{mqsocket: mqsocket}) do
    Exzmq.deliver_close(mqsocket)
    :ok
  end

  def code_change(_old_vsn, state_name, state, _extra) do
    {:ok, state_name, state}
  end

  def exec_sync(msg, state_name, state) do
    apply(__MODULE__, state_name, [{:in, msg}, state])
  end

  def handle_data_reply(reply) when elem(reply, 0) === :next_state do
    handle_data(elem(reply, 1), elem(reply, 2), reply)
  end
  def handle_data_reply(reply) do
    reply
  end

  def send_frames(frames, next_state_info) do
    packet = Frame.encode(frames)
    send_packet(packet, next_state_info)
  end

  def send_packet(packet, next_state_info) do
    state = elem(next_state_info, 2)
    socket = state.socket
    case :gen_tcp.send(socket, packet) do
      :ok ->
        :ok = :inet.setopts(socket, [{:active, :once}])
        next_state_info
      {:error, reason} ->
        {:stop, reason, state}
    end
  end

end
