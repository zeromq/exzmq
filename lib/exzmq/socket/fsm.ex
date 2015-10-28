## This Source Code Form is subject to the terms of the Mozilla Public
## License, v. 2.0. If a copy of the MPL was not distributed with this
## file, You can obtain one at http://mozilla.org/MPL/2.0/.
defmodule Exzmq.Socket.Fsm do

 
  @type transport :: pid
  @type check_type :: :'send' | :'dequeue_send' | :'deliver' | :'deliver_recv' | :'recv'
  @type do_type :: :'queue_send' | {:'deliver_send', list(transport)} | {:'deliver', transport} | {:'queue', transport} | {:'dequeue', transport}

  alias Exzmq.Socket.FsmState

    def init(module, opts, mqsstate) do

        case apply(module, :init, [opts]) do
            {:ok, state_name, state} ->

                fsm = %FsmState{module: module, state_name: state_name, state: state}
                mqsstate1 = %{mqsstate | fsm: fsm}
                {:ok, mqsstate1}
            reply ->
                {reply, mqsstate}
        end
    end

    # check actions do not alter the state of the FSM
    def check(action, mqsstate = %Exzmq.Socket{fsm: fsm}) do

        %FsmState{module: module, state_name: state_name, state: state} = fsm


        r = apply(module, state_name,[:check, action, mqsstate, state])

        #?DEBUG("ezmq_socket_fsm state: ~w, check: ~w, Result: ~w~n", [StateName, Action, R]),
        r
    end

    def work(action, mqsstate = %Exzmq.Socket{fsm: fsm}) do
        %FsmState{module: module, state_name: state_name, state: state} = fsm

        case apply(module, state_name, [:do, action, mqsstate, state]) do
            {:error, reason} ->
                :error_logger.error_msg("socket fsm for ~w exited with ~p, (~p,~p)~n", [action, reason, mqsstate, state])
                :erlang.error(reason);
            {:next_state, next_state_name, next_mqsstate, next_state} ->
                #?DEBUG("ezmq_socket_fsm: state: ~w, Action: ~w, next_state: ~w~n", [StateName, Action, NextStateName]),
                new_fsm = %{fsm | state_name: next_state_name, state: next_state}
                %{next_mqsstate | fsm: new_fsm}
        end
    end

    def close(transport, mqsstate = %Exzmq.Socket{fsm: fsm}) do
        %FsmState{module: module, state_name: state_mame, state: state} = fsm

        case apply(module, :close, [state_mame, transport, mqsstate, state]) do
            {:error, reason} ->
                :error_logger.error_msg("socket fsm for ~w exited with ~p, (~p,~p)~n", [transport, reason, mqsstate, state])
                :erlang.error(reason)
            {:next_state, next_state_name, next_mqsstate, next_state} ->
                #?DEBUG("ezmq_socket_fsm: state: ~w, Action: ~w, next_state: ~w~n", [StateName, Action, NextStateName]),
                new_fsm = %{fsm | state_name: next_state_name, state: next_state}
                %{next_mqsstate | fsm: new_fsm}
        end
    end

    def encap_msg({transport, msg}, mqsstate = %Exzmq.Socket{fsm: fsm})
      when is_pid(transport) or is_list(msg) do
        %FsmState{module: module, state_name: state_name, state: state} = fsm
        apply(module, :encap_msg,[{transport, msg}, state_name, mqsstate, state])
    end

    def encap_msg({transport, msg = {_identity, parts}}, mqsstate = %Exzmq.Socket{fsm: fsm})
      when is_pid(transport) or is_list(parts) do
        %FsmState{module: module, state_name: state_name, state: state} = fsm
        module.encap_msg({transport, msg}, state_name, mqsstate, state)
    end

    def decap_msg(transport, id_msg = {_, msg}, mqsstate = %Exzmq.Socket{fsm: fsm})
      when is_pid(transport) or is_list(msg) do
        %FsmState{module: module, state_name: state_name, state: state} = fsm
        module.decap_msg(transport, id_msg, state_name, mqsstate, state)
    end
end