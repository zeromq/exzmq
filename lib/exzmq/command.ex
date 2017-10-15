## This Source Code Form is subject to the terms of the Mozilla Public
## License, v. 2.0. If a copy of the MPL was not distributed with this
## file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Exzmq.Command do

  @moduledoc """
  This module contains helpers to encode/decode commands as per ZeroMQ spec.
  """

  def encode_ready(type, metadata \\ %{}) do
  encoded_metadata = metadata
  |> Map.put(:"Server-Type", type)
  |> encode_metadata
  #metadata_size = encoded_metadata |> byte_size
  ready = [<<0xd5, "READY">>, encoded_metadata] |> IO.iodata_to_binary
  ready_size = ready |> byte_size
  if ready_size <= 255  do
    [<<0x04, ready_size::size(8)>>, ready] |> IO.iodata_to_binary
  else
    [<<0x06, ready_size::size(64)>>, ready] |> IO.iodata_to_binary
  end
  end

  def encode_metadata(metadata) do
    metadata
    |> Enum.map_reduce([], fn(e, acc) ->
      {k,v} = e
      ks = k |> Atom.to_string
      kl = ks |> String.length
      vl = v |> String.length
      acc = acc ++ [kl, ks, <<vl::size(32)>>, v]
      {e, acc}
      end)
    |> elem(1)
    |> IO.iodata_to_binary
  end

end
