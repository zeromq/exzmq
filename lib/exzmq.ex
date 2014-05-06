## This Source Code Form is subject to the terms of the Mozilla Public
## License, v. 2.0. If a copy of the MPL was not distributed with this
## file, You can obtain one at http://mozilla.org/MPL/2.0/.
defmodule Exzmq do
  use GenServer.Behaviour 
  @server_opts {}

    defrecord Socket, owner: nil, fsm: nil, identity: "",
          # delivery mechanism
          mode: :passive, # :: 'active'|'active_once'|'passive',
          recv_q: [], #the queue of all recieved messages, that are blocked by a send op
          pending_recv: :none, #tuple()|'none',
          send_q: [], #%% the queue of all messages to send
          pending_send:  :none, #:: tuple()|'none',

          # all our registered transports
          connecting: :orddict.new(),
          listen_trans: :orddict.new(),
          transports: [],
          remote_ids: :orddict.new() do
          record_type owner: pid, fsm: term, identity: binary, mode: :'active'|:'active_once'|:'passive'
    end

    defrecord Cargs, family: nil, address: nil, port: nil, tcpopts: nil, timeout: nil, failcnt: nil

    def start_link(opts) when is_list(opts) do
       :gen_server.start_link(__MODULE__, {self(), opts}, [@server_opts])
    end

    @doc ~S"""
    Create a zeromq socket

    ## Example

    { :ok, socket } = Exzmq.start([{:type, :req}])
    Exzmq.connect(socket, :tcp, {127,0,0,1}, 5555, [])
    
    """
    def start(opts) when is_list(opts) do
        :gen_server.start(__MODULE__, {self(), opts}, [@server_opts])
    end

    def socket_link(opts) when is_list(opts) do
        start_link(opts)
    end

    @doc ~S"""
    Create a zeromq socket

    ## Example

    { :ok, socket } = Exzmq.socket([{:type, :req}])
    Exzmq.connect(socket, :tcp, {127,0,0,1}, 5555, [])
    
    """
    def socket(opts) when is_list(opts) do
        start(opts)
    end

    @doc ~S"""
    Accept connections on a socket

    ## Example

    {:ok, socket} = Exzmq.start([{:type, :rep}])
    Exzmq.bind(socket, :tcp, port, []))
    
    """
    # todo create macro when port?(port)
    def bind(socket, :tcp, port, opts)  do

        valid = case Dict.get(opts, :ip) do
            nil -> {:ok, nil};
            address -> validate_address(address)
        end

        #TODO: socket options
        case valid do
            {:ok, _} -> :gen_server.call(socket, {:bind, :tcp, port, opts});
            res -> res
        end
    end
    
    @doc ~S"""
    Connect a socket

    ## Example

    {:ok, socket} = Exzmq.start([{:type, :req}])
    Exzmq.connect(socket, :tcp, {127,0,0,1}, 5555, [])
    
    """
    #todo macro port?
    def connect(socket, :tcp, address, port, opts) do 


        valid = validate_address(address)
        case valid do
            {:ok, _} -> :gen_server.call(socket, {:connect, :tcp, address, port, opts})
            res -> res
        end
    end

    @doc ~S"""
    close ØMQ socket

    ## Example

    {:ok, socket} = Exzmq.start([{:type, :req}])
    Exzmq.close(socket)
    
    """
    def close(socket) do
        :gen_server.call(socket, :close)
    end

    @doc ~S"""
    send a message on a socket

    ## Example

    {:ok, socket} = Exzmq.start([{:type, :req}])
    Exzmq.send(socket, [<<"Hello",0>>])
    
    """
    def send(socket, msg) when is_pid(socket) or is_list(msg) do
        :gen_server.call(socket, {:send, msg}, :infinity)
    end

    def send(socket, msg = {_identity, parts}) 
    when is_pid(socket)  or is_list(parts) do
        :gen_server.call(socket, {:send, msg}, :infinity)
    end

    @doc ~S"""
    Receive a message from a socket

    ## Example

    {:ok, socket} = Exzmq.start([{:type, :rep}])
    Exzmq.bind(socket, :tcp, 5555, [])
    Exzmq.recv(socket)
    
    """
    def recv(socket) do
        :gen_server.call(socket, {:recv, :infinity}, :infinity)
    end

    def recv(socket, timeout) do
        :gen_server.call(socket, {:recv, timeout}, :infinity)
    end
    
    @doc ~S"""
    set ØMQ socket options
   
    """
    def setopts(socket, opts) do
        :gen_server.call(socket, {:setopts, opts})
    end

    def deliver_recv(socket, id_msg) do
        :gen_server.cast(socket, {:deliver_recv, self(), id_msg})
    end

    def deliver_accept(socket, remote_id) do
        :gen_server.cast(socket, {:deliver_accept, self(), remote_id})
    end

    def deliver_connect(socket, reply) do
        :gen_server.cast(socket, {:deliver_connect, self(), reply})
    end

    def deliver_close(socket) do
        :gen_server.cast(socket, {:deliver_close, self()})
    end

    """
    load balance sending sockets
    - simple round robin

    CHECK: is 0MQ actually doing anything else?
    """
    def lb(transports, mqsstate = Exzmq.Socket[transports: trans]) when is_list(transports) do
        trans1 = :lists.subtract(trans, transports) ++ transports
        mqsstate.update(transports: trans1)
    end

    def lb(transport, mqsstate = Exzmq.Socket[transports: trans]) do
        trans1 = :lists.delete(transport, trans) ++ [transport]
        mqsstate.update(transports: trans1)
    end

    defp validate_address(address) when is_binary(address) do 
        :inet.gethostbyname(address)
    end

    defp validate_address(address) when is_tuple(address) do
        :inet.gethostbyaddr(address)
    end

    defp validate_address(_address) do
        exit(:badarg)
    end

    # transport helpers
    def transports_get(pid, _) when is_pid(pid) do
      pid
    end

    def transports_get(remote_id, Exzmq.Socket[remote_ids: rem_ids]) do
      case :orddict.find(remote_id, rem_ids) do
          {:ok, pid} -> pid
          _ -> :none
      end
    end

    def remote_id_assign(<<>>) do
      make_ref()
    end

    def remote_id_assign(id) when is_binary(id) do
      id
    end

    def remote_id_exists(<<>>, Exzmq.Socket[]) do
      false
    end

    def remote_id_exists(remote_id, Exzmq.Socket[remote_ids: rem_ids]) do
      :orddict.is_key(remote_id, rem_ids)
    end

    def remote_id_add(transport, remote_id, mqsstate = Exzmq.Socket[remote_ids: rem_ids]) do
       mqsstate.update(remote_ids: :orddict.store(remote_id, transport, rem_ids))
    end

    def remote_id_del(transport, mqsstate = Exzmq.Socket[remote_ids: rem_ids]) when is_pid(transport) do
      mqsstate.update(remote_ids: :orddict.filter(fn(_key, value) -> value != transport end, rem_ids))
    end
    
    def remote_id_del(remote_id, mqsstate = Exzmq.Socket[remote_ids: rem_ids]) do
       mqsstate.update(remote_ids: :orddict.erase(remote_id, rem_ids))
    end

    def transports_is_active(transport, Exzmq.Socket[transports: transports]) do
      :lists.member(transport, transports)
    end

    def transports_activate(transport, remote_id, mqsstate = Exzmq.Socket[transports: transports]) do
      mqsstate1 = remote_id_add(transport, remote_id, mqsstate)
      mqsstate1.update(transports: [transport|transports])
    end

    def transports_deactivate(transport, mqsstate = Exzmq.Socket[transports: transports]) do
      mqsstate1 = remote_id_del(transport, mqsstate)
      mqsstate1.update(transports: :lists.delete(transport, transports))
    end

    def transports_while(fun, data, default, Exzmq.Socket[transports: transports]) do
      do_transports_while(fun, data, transports, default)
    end

    def transports_connected(Exzmq.Socket[transports: transports]) do
      transports != []
    end

    """ 
      walk the list of transports
    - this is intended to hide the details of the transports impl.
    """
    def do_transports_while(_fun, _data, [], default) do
      default
    end

    def do_transports_while(fun, data, [head|rest], default) do
        case fun.(head, data) do
            :continue -> do_transports_while(fun, data, rest, default)
            resp -> resp
        end
    end

    #===================================================================
    # gen_server callbacks
    #===================================================================

    """
     @private
     @doc
     Initializes the server
    
     @spec init(Args) -> {ok, State} |
     {ok, State, Timeout} |
     ignore |
     {stop, Reason}
     @end
    """
    defp socket_types(type) do
      supmod = [{:req, Exzmq.Socket.Req}, {:rep, Exzmq.Socket.Rep},
                {:dealer, Exzmq.Socket.Dealer}, {:router, Exzmq.Socket.Router},
                {:pub, Exzmq.Socket.Pub}, {:sub, Exzmq.Socket.Sub},
                {:push, Exzmq.Socket.Push}, {:pull, Exzmq.Socket.Pull}]
      :proplists.get_value(type, supmod)
    end
            
    def init({owner, opts}) do
        case socket_types(:proplists.get_value(:type, opts, :req)) do
            :undefined ->
                {:stop, :invalid_opts};
            type ->
                init_socket(owner, type, opts)
        end
    end

    def init_socket(owner, type, opts) do
       Process.flag(:trap_exit, true)
       mqsstate0 = Exzmq.Socket[owner: owner, mode: :passive, recv_q: :orddict.new(), connecting: :orddict.new(), listen_trans: :orddict.new(), transports: [], remote_ids: :orddict.new()]
       mqsstate1 = :lists.foldl(&do_setopts/2, mqsstate0, :proplists.unfold(opts))
       Exzmq.Socket.Fsm.init(type, opts, mqsstate1)
    end

    """
    --------------------------------------------------------------------
    %% @private
    %% @doc
    %% Handling call messages
    %%
    %% @spec handle_call(Request, From, State) ->
    %% {reply, Reply, State} |
    %% {reply, Reply, State, Timeout} |
    %% {noreply, State} |
    %% {noreply, State, Timeout} |
    %% {stop, Reason, Reply, State} |
    %% {stop, Reason, State}
    %% @end
    """
    def handle_call({:bind, :tcp, port, opts}, _from, mqsstate = Exzmq.Socket[identity: identity]) do
        tcpopts0 = [:binary,:inet, {:active,false}, {:send_timeout,5000}, {:backlog,10}, {:nodelay,true}, {:packet,:raw}, {:reuseaddr,true}]
        tcpopts1 = case :proplists.get_value(:ip, opts) do
                       :undefined -> tcpopts0
                       i -> [{:ip, i}|tcpopts0]
                   end
        #?DEBUG("bind: ~p~n", [TcpOpts1]),
        case Exzmq.Tcp.Socket.start_link(identity, port, tcpopts1) do
            {:ok, pid} ->
                listen = :orddict.append(pid, {:tcp, port, opts}, mqsstate.listen_trans)
                {:reply, :ok, mqsstate.update(listen_trans: listen)}
            reply ->
                {:reply, reply, mqsstate}
        end
    end

    def handle_call({:connect, :tcp, address, port, opts}, _from, state) do
        tcpopts = [:binary, :inet, {:active,false}, {:send_timeout,5000}, {:nodelay,true}, {:packet,:raw}, {:reuseaddr,true}]
        timeout = :proplists.get_value(:timeout, opts, 5000)
        connect_args = Cargs[family:  :tcp, address: address, port: port, tcpopts: tcpopts,
                             timeout: timeout, failcnt: 0]
        newstate = do_connect(connect_args, state)
        {:reply, :ok, newstate}
    end

    def handle_call(:close, _from, state) do
        {:stop, :normal, :ok, state}
    end

    def handle_call({:recv, _timeout}, _from, Exzmq.Socket[mode: mode] = state)
      when mode != :passive do
        {:reply, {:error, :active}, state}
    end

    def handle_call({:recv, _timeout}, _from, Exzmq.Socket[pending_recv: pending_recv] = state)
      when pending_recv != :none do
        reply = {:error, :already_recv}
        {:reply, reply, state}
    end

    def handle_call({:recv, timeout}, from, state) do
        handle_recv(timeout, from, state)
    end

    def handle_call({:send, msg}, from, state) do
        case Exzmq.Socket.Fsm.check({:send, msg}, state) do
            {:queue, action} ->
                #TODO: HWM and swap to disk....
                state1 = state.update(send_q: state.send_q ++ [msg])
                state2 = Exzmq.Socket.Fsm.work(:queue_send, state1)
                case action do
                    :return ->
                        state3 = check_send_queue(state2)
                        {:reply, :ok, state3}
                    :block ->
                        state3 = state2.update(pending_send: from)
                        state4 = check_send_queue(state3)
                        {:noreply, state4}
                end
            {:drop, reply} ->
                {:reply, reply, state}
            {:error, reason} ->
                {:reply, {:error, reason}, state}
            {:ok, transports} ->
                ezmq_link_send({transports, msg}, state)
                state1 = Exzmq.Socket.Fsm.work({:deliver_send, transports}, state)
                state2 = queue_run(state1)
                {:reply, :ok, state2}
        end
    end

    def handle_call({:setopts, opts}, _from, state) do
        new_state = :lists.foldl(&do_setopts/2, state, :proplists.unfold(opts))
        {:reply, :ok, new_state}
    end

    """
    --------------------------------------------------------------------
    %% @private
    %% @doc
    %% Handling cast messages
    %%
    %% @spec handle_cast(Msg, State) -> {noreply, State} |
    %% {noreply, State, Timeout} |
    %% {stop, Reason, State}
    %% @end
    %%--------------------------------------------------------------------
    """

    def handle_cast({:deliver_accept, transport, remote_id}, state) do
        Process.link(transport)
        state1 = transports_activate(transport, remote_id, state)
        #?DEBUG("DELIVER_ACCPET: ~p~n", [State1]),
        state2 = send_queue_run(state1)
        {:noreply, state2}
    end

    def handle_cast({:deliver_connect, transport, {:ok, remote_id}}, state) do
        state1 = transports_activate(transport, remote_id, state)
        state2 = send_queue_run(state1)
        {:noreply, state2}
    end

    def handle_cast({:deliver_connect, transport, reply}, state = Exzmq.Socket[connecting: connecting]) do
        case reply do
            # transient errors
            {:error, reason} when reason == :eagain or 
                                  reason == :ealready or
                                  reason == :econnrefused or 
                                  reason == :econnreset ->
                connect_args = :orddict.fetch(transport, connecting)
                #?DEBUG("CArgs: ~w~n", [ConnectArgs]),
                :erlang.send_after(3000, self(), {:reconnect, connect_args.update(failcnt: connect_args.failcnt + 1)})
                state2 = state.update(connecting:  :orddict.erase(transport, connecting))
                {:noreply, state2}
            _ ->
                state1 = state.update(connecting:  :orddict.erase(transport, connecting))
                state2 = check_send_queue(state1)
                {:noreply, state2}
        end
    end

    def handle_cast({:deliver_close, transport}, state = Exzmq.Socket[connecting: connecting]) do
        Process.unlink(transport)
        state0 = transports_deactivate(transport, state)
        state1 = queue_close(transport, state0)
        state2 = Exzmq.Socket.Fsm.close(transport, state1)
        state3 = case :orddict.find(transport, connecting) do
                     {:ok, connect_args} ->
                         :erlang.send_after(3000, self(), {:reconnect, connect_args.update(failcnt:  0)})
                         state2.update(connecting: :orddict.erase(transport, connecting))
                     _ ->
                         check_send_queue(state2)
                 end
        _state4 = queue_run(state3)
        #?DEBUG("DELIVER_CLOSE: ~p~n", [_State4]),
        {:noreply, state3}
    end

    def handle_cast({:deliver_recv, transport, id_msg}, state) do
        handle_deliver_recv(transport, id_msg, state)
    end

    def handle_cast(_msg, state) do
        {:noreply, state}
    end

    """
    --------------------------------------------------------------------
    %% @private
    %% @doc
    %% Handling all non call/cast messages
    %%
    %% @spec handle_info(Info, State) -> {noreply, State} |
    %% {noreply, State, Timeout} |
    %% {stop, Reason, State}
    %% @end
    %%--------------------------------------------------------------------
    """

    def handle_info(:recv_timeout, Exzmq.Socket[pending_recv:  {from, _}] = state) do
        :gen_server.reply(from, {:error, :timeout})
        state1 = state.update(pending_recv: :none)
        {:noreply, state1}
    end

    def handle_info({:reconnect, connect_args}, Exzmq.Socket[] = state) do
        new_state = do_connect(connect_args, state)
        {:noreply, new_state}
    end

    def handle_info({:'EXIT', pid, _reason}, mqsstate) do
        case transports_is_active(pid, mqsstate) do
            true ->
                handle_cast({:deliver_close, pid}, mqsstate)
            _ ->
                {:noreply, mqsstate}
        end
    end

    def handle_info(_info, state) do
        {:noreply, state}
    end
    
    """
    --------------------------------------------------------------------
    %% @private
    %% @doc
    %% This function is called by a gen_server when it is about to
    %% terminate. It should be the opposite of Module:init/1 and do any
    %% necessary cleaning up. When it returns, the gen_server terminates
    %% with Reason. The return value is ignored.
    %%
    %% @spec terminate(Reason, State) -> void()
    %% @end
    %%--------------------------------------------------------------------
    """

    def terminate(_reason, _state) do
        :ok
    end

    """
    --------------------------------------------------------------------
    %% @private
    %% @doc
    %% Convert process state when code is changed
    %%
    %% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
    %% @end
    %%--------------------------------------------------------------------
    """

    def code_change(_old_vsn, state, _extra) do
        {:ok, state}
    end


    #%%%===================================================================
    #%%% Internal functions
    #%%%===================================================================

    defp do_connect(connect_args = Cargs[family:  :tcp], mqsstate = Exzmq.Socket[identity:  identity]) do
        #?DEBUG("starting connect: ~w~n", [ConnectArgs]),
        Cargs[address: address, port: port, tcpopts: tcp_opts,
               timeout: timeout, failcnt: _fail_cnt] = connect_args
        {:ok, transport} = Exzmq.Link.start_connection()
        Exzmq.Link.connect(identity, transport, :tcp, address, port, tcp_opts, timeout)
        connecting = :orddict.store(transport, connect_args, mqsstate.connecting)
        mqsstate.update(connecting: connecting)
    end

    defp check_send_queue(mqsstate = Exzmq.Socket[send_q: []]) do
        mqsstate
    end

    defp check_send_queue(mqsstate = Exzmq.Socket[connecting: connecting, listen_trans: listen]) do
        case {transports_connected(mqsstate), :orddict.size(connecting), :orddict.size(listen)} do
            {:false, 0, 0} -> clear_send_queue(mqsstate)
            _ -> mqsstate
        end
    end

    defp clear_send_queue(state = Exzmq.Socket[send_q: []]) do
        state
    end

    defp clear_send_queue(state = Exzmq.Socket[send_q: [_msg], pending_send: from])
      when From != :none do
        :gen_server.reply(from, {:error, :no_connection})
        state1 = Exzmq.Socket.Fsm.work({:deliver_send, :abort}, state)
        state1.update(send_q: [], pending_send: :none)
    end

    defp clear_send_queue(state = Exzmq.Socket[send_q:  [_msg|rest]]) do
        state1 = Exzmq.Socket.Fsm.work({:deliver_send, :abort}, state)
        clear_send_queue(state1.update(send_q: rest))
    end

    defp send_queue_run(state = Exzmq.Socket[send_q:  []]) do
        state
    end

    defp send_queue_run(state = Exzmq.Socket[send_q: [msg], pending_send: from])
      when from != :none do
        case Exzmq.Socket.Fsm.check(:dequeue_send, state) do
            {:ok, transports} ->
                ezmq_link_send({transports, msg}, state)
                state1 = Exzmq.Socket.Fsm.work({:deliver_send, transports}, state)
                :gen_server.reply(from, :ok)
                state1.update(send_q: [], pending_send: :none)
            _ ->
                state
        end
    end

    defp send_queue_run(state = Exzmq.Socket[send_q: [msg|rest]]) do
        case Exzmq.Socket.Fsm.check(:dequeue_send, state) do
            {:ok, transports} ->
                ezmq_link_send({transports, msg}, state)
                state1 = Exzmq.Socket.Fsm.work({:deliver_send, transports}, state)
                send_queue_run(state1[send_q: rest]);
            _ ->
                state
        end
    end
        
    # check if should deliver the 'top of queue' message
    defp queue_run(state) do
        case Exzmq.Socket.Fsm.check(:deliver, state) do
            :ok -> queue_run_2(state);
            _ -> state
        end
    end 

    defp queue_run_2(Exzmq.Socket[mode: mode] = state)
      when mode == :active or mode == :active_once do
        run_recv_q(state)
    end

    defp queue_run_2(Exzmq.Socket[pending_recv: {_from, _ref}] = state) do
        run_recv_q(state)
    end

    defp queue_run_2(Exzmq.Socket[mode: :passive] = state) do
        state
    end

    defp run_recv_q(state) do
        case dequeue(state) do
            {{transport, id_msg}, state0} ->
                send_owner(transport, id_msg, state0)
            _ ->
                state
        end
    end

    defp cond_cancel_timer(:none) do 
        :ok
    end
         
    defp cond_cancel_timer(ref) do
        _ = :erlang.cancel_timer(ref)
        :ok
    end

    # send a specific message to the owner
    defp send_owner(transport, id_msg, Exzmq.Socket[pending_recv: {from, ref}] = state) do
        :ok = cond_cancel_timer(ref)
        state1 = state.update(pending_recv: :none)
        :gen_server.reply(from, {:ok, Exzmq.Socket.Fsm.decap_msg(transport, id_msg, state)})
        Exzmq.Socket.Fsm.work({:deliver, transport}, state1)
    end

    defp send_owner(transport, id_msg, Exzmq.Socket[owner: owner, mode: mode] = state)
      when mode == :active or mode == :active_once do
        Kernel.send owner, {:zmq, self(), Exzmq.Socket.Fsm.decap_msg(transport, id_msg, state)}
        new_state = Exzmq.Socket.Fsm.work({:deliver, transport}, state)
        next_mode(new_state)
    end

    defp next_mode(Exzmq.Socket[mode: :active] = state) do
        queue_run(state)
    end
    
    defp next_mode(Exzmq.Socket[mode: :active_once] = state) do
        state.update(mode: :passive)
    end

    defp handle_deliver_recv(transport, id_msg, mqsstate) do
        #?DEBUG("deliver_recv: ~w, ~w~n", [Transport, IdMsg]),
        case Exzmq.Socket.Fsm.check({:deliver_recv, transport}, mqsstate) do
            :ok ->
                mqsstate0 = handle_deliver_recv_2(transport, id_msg, queue_size(mqsstate), mqsstate)
                {:noreply, mqsstate0}
            {:error, _reason} ->
                {:noreply, mqsstate}
        end
    end

    defp handle_deliver_recv_2(transport, id_msg, 0, Exzmq.Socket[mode: mode] = mqsstate)
      when mode == :active or mode == :active_once do
        case Exzmq.Socket.Fsm.check(:deliver, mqsstate) do
            :ok -> send_owner(transport, id_msg, mqsstate)
            _ -> queue(transport, id_msg, mqsstate)
        end
    end

    defp handle_deliver_recv_2(transport, id_msg, 0, Exzmq.Socket[pending_recv: {_from, _ref}] = mqsstate) do
        case Exzmq.Socket.Fsm.check(:deliver, mqsstate) do
            :ok -> send_owner(transport, id_msg, mqsstate)
            _ -> queue(transport, id_msg, mqsstate)
        end
    end

    defp handle_deliver_recv_2(transport, id_msg, _, mqsstate) do
        queue(transport, id_msg, mqsstate)
    end

    defp handle_recv(timeout, from, mqsstate) do

        case Exzmq.Socket.Fsm.check(:recv, mqsstate) do
            {:error, reason} ->
                {:reply, {:error, reason}, mqsstate};
            :ok ->
                handle_recv_2(timeout, from, queue_size(mqsstate), mqsstate)
        end
    end

    defp handle_recv_2(timeout, from, 0, state) do
        ref = case timeout do
                  :infinity -> :none;
                  _ -> :erlang.send_after(timeout, self(), :recv_timeout)
              end
        state1 = state.update(pending_recv: {from, ref})
        {:noreply, state1}
    end

    defp handle_recv_2(_timeout, _from, _, state) do
        case dequeue(state) do
            {{transport, id_msg}, state0} ->
                state2 = Exzmq.Socket.Fsm.work({:deliver, transport}, state0)
                {:reply, {:ok, Exzmq.Socket.Fsm.decap_msg(transport, id_msg, state)}, state2}
            _ ->
                {:reply, {:error, :internal}, state}
        end
    end

    def simple_encap_msg(msg) when is_list(msg) do
        :lists.map(fn(m) -> {:normal, m} end, msg)
    end

    def simple_decap_msg(msg) when is_list(msg) do
        :lists.reverse(:lists.foldl(fn({:normal, m}, acc) -> [m|acc]
                                                 (_, acc) -> acc 
                                    end, [], msg))
    end
                           
    defp ezmq_link_send({transports, msg}, state) when is_list(transports) do
        :lists.foreach(fn(t) ->
                              msg1 = Exzmq.Socket.Fsm.encap_msg({t, msg}, state)
                              Exzmq.Link.send(t, msg1)
                       end, transports)
    end

    defp ezmq_link_send({transport, msg}, state) do
        Exzmq.Link.send(transport, Exzmq.Socket.Fsm.encap_msg({transport, msg}, state))
    end

    """
    %%
    %% round robin queue
    %%
    """

    defp queue_size(Exzmq.Socket[recv_q: q]) do
        :orddict.size(q)
    end

    defp queue(transport, value, mqsstate = Exzmq.Socket[recv_q: q]) do
        q1 = :orddict.update(transport, fn(v) -> :queue.in(value, v) end,
                            :queue.from_list([value]), q)
        mqsstate1 = mqsstate.update(recv_q: q1)
        Exzmq.Socket.Fsm.work({:queue, transport}, mqsstate1)
    end

    defp queue_close(transport, mqsstate = Exzmq.Socket[recv_q: q]) do
        q1 = :orddict.erase(transport, q)
        mqsstate.update(recv_q: q1)
    end
        
    defp dequeue(mqsstate = Exzmq.Socket[recv_q: q]) do
        #?DEBUG("TRANS: ~p, PENDING: ~p~n", [MqSState#ezmq_socket.transports, Q]),
        case transports_while(&do_dequeue/2, q, :empty, mqsstate) do
            {{transport, value}, q1} ->
                mqsstate0 = mqsstate.update(recv_q: q1)
                mqsstate1 = Exzmq.Socket.Fsm.work({:dequeue, transport}, mqsstate0)
                mqsstate2 = lb(transport, mqsstate1)
                {{transport, value}, mqsstate2}
            reply ->
                reply
        end
    end

    defp do_dequeue(transport, q) do
        case :orddict.find(transport, q) do
            {:ok, v} ->
                {{:value, value}, v1} = :queue.out(v)
                q1 = case :queue.is_empty(v1) do
                         true -> :orddict.erase(transport, q)
                         false -> :orddict.store(transport, v1, q)
                     end
                    {{transport, value}, q1}
            _ ->
                :continue
        end
    end

    defp do_setopts({:identity, id}, mqsstate) do
        mqsstate.update(identity: iodata_to_binary(id))
    end

    defp do_setopts({:active, :once}, mqsstate) do
        run_recv_q(mqsstate.update(mode: :active_once))
    end

    defp do_setopts({:active, true}, mqsstate) do
        run_recv_q(mqsstate.update(mode: :active))
    end
        
    defp do_setopts({:active, false}, mqsstate) do
        mqsstate.update(mode: :passive)
    end

    defp do_setopts(_, mqsstate) do
       mqsstate
    end

end
