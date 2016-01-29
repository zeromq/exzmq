## This Source Code Form is subject to the terms of the Mozilla Public
## License, v. 2.0. If a copy of the MPL was not distributed with this
## file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Exzmq.Socket do

  defstruct socket: nil,
            address: nil,
            acceptor: nil,
            type: nil, # :client or :server
            clients: [], # list of client connections, if socket is of type server
            state: :greeting,
            messages: []

end

