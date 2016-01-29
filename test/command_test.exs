## This Source Code Form is subject to the terms of the Mozilla Public
## License,v. 2.0. If a copy of the MPL was not distributed with this
## file,You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule CommandTest do

  use ExUnit.Case,async: false

  alias Exzmq.Command

  test "shall encode empty metadata" do
  	assert <<>> == Command.encode_metadata(%{})
  end

  test "shall encode metadata" do
  	encoded = Command.encode_metadata(%{"Socket-Type": "SERVER"})
  	assert <<11,83,111,99,107,101,116,45,84,121,112,101,0,0,0,6,83,69,82,86,69,82>> = encoded
  end

  test "shall encode ready" do
  	encoded = Command.encode_ready("SERVER")
  	assert <<4,28,213,82,69,65,68,89,11,83,101,114,118,101,114,45,84,121,112,101,0,0,0,6,83,69,82,86,69,82>> = encoded
  end
	
end