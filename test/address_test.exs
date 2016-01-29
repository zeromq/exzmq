## This Source Code Form is subject to the terms of the Mozilla Public
## License, v. 2.0. If a copy of the MPL was not distributed with this
## file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule AddressTest do

  use ExUnit.Case, async: false

  alias Exzmq.Address

  test "should pass struct unmodified" do
  	address = %Address{transport: :tcp, ip: {127,0,0,1}, port: 5555}
  	^address = address |> Address.parse
  end

  test "should parse address string" do
  	address = %Address{transport: :tcp, ip: {127,0,0,1}, port: 5555}
  	^address = "tcp://127.0.0.1:5555" |> Address.parse
  end

end