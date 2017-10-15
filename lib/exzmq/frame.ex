## This Source Code Form is subject to the terms of the Mozilla Public
## License, v. 2.0. If a copy of the MPL was not distributed with this
## file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Exzmq.Frame do

  def decode(<<0x00, len::size(8), payload::binary>>) do
    payload
  end

  def encode(msg) when is_binary(msg) do
    msg_len = msg |> byte_size
    if msg_len > 255 do
      [<<0x02, msg_len::size(64)>>, msg] |> IO.iodata_to_binary
    else
      [<<0x00, msg_len::size(8)>>, msg] |> IO.iodata_to_binary
    end
  end

end
