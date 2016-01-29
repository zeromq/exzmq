## This Source Code Form is subject to the terms of the Mozilla Public
## License, v. 2.0. If a copy of the MPL was not distributed with this
## file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Exzmq.Socket do

  defstruct socket: nil,
            address: nil,
            type: nil, # :client or :server
            owner: nil,
            fsm: nil,
            identity: "",
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
            remote_ids: :orddict.new()

end

