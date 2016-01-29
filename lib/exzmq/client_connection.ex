## This Source Code Form is subject to the terms of the Mozilla Public
## License, v. 2.0. If a copy of the MPL was not distributed with this
## file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Exzmq.ClientConnection do

  @moduledoc """
  This module represents a client connection.
  It is a connection accepted by :gen_tcp.accept.
  """

  defstruct socket: nil 
 	
end
