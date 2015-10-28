defmodule Exzmq.Link.State do
  
  defstruct mqsocket: nil,
            identity: <<>>,
            remote_id: <<>>,
            socket: nil,
            version: {1,0},
            frames: [],
            pending: <<>>

end
