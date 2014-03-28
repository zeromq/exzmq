## This Source Code Form is subject to the terms of the Mozilla Public
## License, v. 2.0. If a copy of the MPL was not distributed with this
## file, You can obtain one at http://mozilla.org/MPL/2.0/.
defmodule Exzmq.Frame do

  use Bitwise

  @flag_none 0x00
  @flag_more 0x01
  @flag_label 0x80

  def bool(0), do: false
  def bool(1), do: true

  def frame_type(0, 1), do: :label
  def frame_type(_,_), do: :normal

  def decode_greeting(data = <<0xff, length::[size(64), unsigned, integer], 
                                     idflags::size(8), rest::binary>>) do
    decode_greeting({1,0}, length, idflags, rest, data)
  end

  def decode_greeting(data = <<length::[size(8), integer], 
                               idflags::size(8), rest::binary>>) do
    decode_greeting({1,0}, length, idflags, rest, data)
  end

  def decode_greeting(data), do: {:more, data}

  def decode_greeting({1,0}, frame_len, _idflags, msg, data) when size(msg) < frame_len - 1 do
    {:more, data}
  end

  def decode_greeting(ver = {1,0}, frame_len, _idflags, msg, _data) do
    idlen = frame_len - 1
    <<identity::[size(idlen), bytes], rem::binary>> = msg
    {{:greeting, ver, nil, identity}, rem}
  end

  def decode_greeting({1,0}, frame_len, _idflags, msg, _data) do
    idlen = frame_len - 1
    <<_::[size(idlen), bytes], rem::binary>> = msg
    {:invalid, rem}
  end

  def decode(ver, data = <<0xff, length::[size(64), unsigned, integer], 
                                 flags::[size(8), bits], rest::binary>>) do
    decode(ver, length, flags, rest, data)
  end

  def decode(ver, data = <<length::[size(8), integer], flags::[size(8), bits], rest::binary>>) do
    decode(ver, length, flags, rest, data)
  end

  def decode(_ver, data) do
    {:more, data}
  end

  def decode(_ver, frame_len, _flags, _msg, data) when frame_len === 0 do
   {:invalid, data}
  end

  def decode(_ver, frame_len, _flags, msg, data) when size(msg) < frame_len - 1 do
   {:more, data}
  end

  def decode(ver, frame_len, <<label::size(1), _::size(6), more::size(1)>>, msg, _data) do
   flen = frame_len - 1
   <<frame::[size(flen), bytes], rem::binary>> = msg
   {{bool(more), {frame_type(ver, label), frame}}, rem}
  end

  def encode_greeting({1,0}, _socket_type, identity) when is_binary(identity) do
    msg = encode(identity, @flag_none, [], [])
  end

  def encode(msg) when is_list(msg) do
    encode(msg, [])
  end

  def encode([], acc) do
   iolist_to_binary(Enum.reverse(acc))
  end

  def encode([{:label, head}|rest],acc) do
   encode(head, @flag_label, rest, acc)
  end

  def encode([{:normal, head}|rest],acc)  when is_binary(head) or is_list(head) do
    encode(head, @flag_none, rest, acc)
  end

  def encode([head|rest], acc) when is_binary(head) or is_list(head) do
    encode(head, @flag_none, rest, acc)
  end

  def encode(frame, flags, rest, acc) when is_list(frame) do
    encode(iolist_to_binary(frame), flags, rest, acc)
  end

  def encode(frame, flags, rest, acc) when is_binary(frame) do
    length = size(frame) + 1
    
    if length >= 255 do
      header = <<0xff, length::size(64)>>
    else
      header = <<length::size(8)>>
    end

    if length(rest) !== 0 do
      flags1 = bor(flags, @flag_more)
    else
      flags1 = flags
    end
    encode(rest, [<<header::binary, flags1::size(8), frame::binary>>|acc])
  end

end
