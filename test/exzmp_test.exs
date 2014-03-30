## This Source Code Form is subject to the terms of the Mozilla Public
## License, v. 2.0. If a copy of the MPL was not distributed with this
## file, You can obtain one at http://mozilla.org/MPL/2.0/.
defmodule ExzmqTest do
  use ExUnit.Case, async: false
  
  test "open a req socket, bind and close" do
    {:ok, s} = Exzmq.socket([{:type, :req}, {:active, false}, {:identity, "test"}])
    assert Exzmq.bind(s, :tcp, 5555, []) == :ok
    assert Exzmq.close(s) == :ok
  end

  test "open a req socket, connect and close" do 
    {:ok, s} = Exzmq.socket([{:type, :req}, {:active, false}])
    assert Exzmq.connect(s, :tcp, {127,0,0,1}, 5555, []) == :ok
    assert Exzmq.close(s) == :ok
  end
  
  test "open a req socket and connect with a wrong address" do
    {:ok, s} = Exzmq.socket([{:type, :req}, {:active, false}])
    assert Exzmq.connect(s, :tcp, "undefined.undefined", 5555, []) == {:error,:einval} 
    assert Exzmq.close(s) == :ok
  end

  test "open req socket and wait connecting timeout" do
    {:ok, s} = Exzmq.socket([{:type, :req}, {:active, false}])
    :ok = Exzmq.connect(s, :tcp, {127,0,0,1}, 5555, [{:timeout, 1000}])
    :timer.sleep(2000)
    assert Exzmq.close(s) == :ok
  end

  test "open req socket with existing endpoint and wait connecting timeout" do
    Process.spawn(fn() ->
                    {:ok, l} = :gen_tcp.listen(5555,[{:active, false}, {:packet, :raw}, {:reuseaddr, true}])
                    {:ok, s1} = :gen_tcp.accept(l)
                    :timer.sleep(15000) ## keep socket alive for at least 10sec...
                    :gen_tcp.close(s1)  
                  end)
    {:ok, s} = Exzmq.socket([{:type, :req}, {:active, false}])
    :ok = Exzmq.connect(s, :tcp, {127,0,0,1}, 5555, [{:timeout, 1000}])
    :timer.sleep(15000) ## wait for the connection setup timeout
    Exzmq.close(s)
  end

  test "open a dealer socket, bind and close" do
    {:ok, s} = Exzmq.socket([{:type, :dealer}, {:active, false}])
    :ok = Exzmq.bind(s, :tcp, 5555, [])
    Exzmq.close(s)
  end

  test "open a dealer socket, connect and close" do
    {:ok, s} = Exzmq.socket([{:type, :dealer}, {:active, false}])
    :ok = Exzmq.connect(s, :tcp, {127,0,0,1}, 5555, [])
    Exzmq.close(s)
  end

  test "open dealer socket and wait connecting timeout" do
    {:ok, s} = Exzmq.socket([{:type, :dealer}, {:active, false}])
    :ok = Exzmq.connect(s, :tcp, {127,0,0,1}, 5555, [{:timeout, 1000}])
    :ok = Exzmq.connect(s, :tcp, {127,0,0,1}, 5555, [{:timeout, 1000}])
    :ok = Exzmq.connect(s, :tcp, {127,0,0,1}, 5555, [{:timeout, 1000}])
    :ok = Exzmq.connect(s, :tcp, {127,0,0,1}, 5555, [{:timeout, 1000}])
    :timer.sleep(2000)
    Exzmq.close(s)
  end

  test "open req dealer and wait connecting timeout" do
    Process.spawn(fn() ->
                  {:ok, l} = :gen_tcp.listen(5555,[{:active, false}, {:packet, :raw}, {:reuseaddr, true}])
                  {:ok, s1} = :gen_tcp.accept(l)
                  :timer.sleep(15000) ## keep socket alive for at least 10sec...
                  :gen_tcp.close(s1)  end)
    {:ok, s} = Exzmq.socket([{:type, :dealer}, {:active, false}])
    :ok = Exzmq.connect(s, :tcp, {127,0,0,1}, 5555, [{:timeout, 1000}])
    :ok = Exzmq.connect(s, :tcp, {127,0,0,1}, 5555, [{:timeout, 1000}])
    :ok = Exzmq.connect(s, :tcp, {127,0,0,1}, 5555, [{:timeout, 1000}])
    :ok = Exzmq.connect(s, :tcp, {127,0,0,1}, 5555, [{:timeout, 1000}])
    :timer.sleep(15000) ## wait for the connection setup timeout
    Exzmq.close(s)
  end

  test "open req socket and send trash" do
    self = self()
    Process.spawn(fn() ->
                  {:ok, l} = :gen_tcp.listen(5555,[{:active, false}, {:packet, :raw}, {:reuseaddr, true}])
                  {:ok, s1} = :gen_tcp.accept(l)
                  t = <<1,0xFF,"TRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASH">>
                  :gen_tcp.send(s1, iolist_to_binary([t,t,t,t,t]))
                  :timer.sleep(500)
                  :gen_tcp.close(s1)
                  send(self, :done)
          end)
    {:ok, s} = Exzmq.socket([{:type, :req}, {:active, false}])
    :ok = Exzmq.connect(s, :tcp, {127,0,0,1}, 5555, [{:timeout, 1000}])
    
    assert_receive :done, 1000
    Exzmq.close(s)
  end

  test "open rep socket and send trash" do
    self = self()
    {:ok, s} = Exzmq.socket([{:type, :rep}, {:active, false}])
    :ok = Exzmq.bind(s, :tcp, 5555, [])
    Process.spawn(fn() ->
                  {:ok, l} = :gen_tcp.connect({127,0,0,1},5555,[{:active, false}, {:packet, :raw}])
                  t = <<1,0xFF,"TRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASH">>
                  :gen_tcp.send(l, iolist_to_binary([t,t,t,t,t]))
                  :timer.sleep(500)
                  :gen_tcp.close(l)
                  send(self, :done) end)
     
    assert_receive :done, 1000
    Exzmq.close(s)
  end

  test "open a rep socket and wait time out" do
      {:ok, s} = Exzmq.socket([{:type, :rep}, {:active, false}])
      :ok = Exzmq.bind(s, :tcp, 5555, [])
      Process.spawn(fn() ->
                    {:ok, l} = :gen_tcp.connect({127,0,0,1},5555,[{:active, false}, {:packet, :raw}])
                    :timer.sleep(15000) ## keep socket alive for at least 10sec...
                    :gen_tcp.close(l) end)

      :timer.sleep(15000) ##wait for the connection setup timeout
      Exzmq.close(s)
  end
   
  def create_multi_connect(_type, _active, _ip, _port, 0, acc) do
    acc
  end

  def create_multi_connect(type, active, ip, port, cnt, acc) do
    {:ok, s2} = Exzmq.socket([{:type, type}, {:active, active}])
    :ok = Exzmq.connect(s2, :tcp, ip, port, [])
    create_multi_connect(type, active, ip, port, cnt - 1, [s2|acc])
  end

  def create_bound_pair_multi(type1, type2, cnt2, mode, ip, port) do
    active = case mode do
              :active -> true
              :passive -> false
    end
    {:ok, s1} = Exzmq.socket([{:type, type1}, {:active, active}])
    :ok = Exzmq.bind(s1, :tcp, port, [])

    s2 = create_multi_connect(type2, active, ip, port, cnt2, [])
    :timer.sleep(10) ## give it a moment to establish all sockets....
    {s1, s2}
  end

  def basic_test_dealer_rep(ip, port, cnt2, mode, size) do
    {s1, s2} = create_bound_pair_multi(:dealer, :rep, cnt2, mode, ip, port)
    msg = String.duplicate("X", size)

    ## send a message for each client Socket and expect a result on each socket
    Enum.each(s2, fn(_s) -> :ok = Exzmq.send(s1, [msg]) end)
    Enum.each(s2, fn(s) -> {:ok, [msg]} = Exzmq.recv(s) end)

    :ok = Exzmq.close(s1)
    Enum.each(s2, fn(s) -> :ok = Exzmq.close(s) end)
  end

  def basic_test_dealer_req(ip, port, cnt2, mode, size) do
    {s1, s2} = create_bound_pair_multi(:dealer, :req, cnt2, mode, ip, port)
    msg = String.duplicate("X", size)

    ## send a message for each client Socket and expect a result on each socket
    Enum.each(s2, fn(s) -> :ok = Exzmq.send(s, [msg]) end)
    Enum.each(s2, fn(_s) -> {:ok, [msg]} = Exzmq.recv(s1) end)

    :ok = Exzmq.close(s1)
    Enum.each(s2, fn(s) -> :ok = Exzmq.close(s) end)
  end

  test "basic test dealer" do
    basic_test_dealer_req({127,0,0,1}, 5559, 10, :passive, 3)
    basic_test_dealer_rep({127,0,0,1}, 5560, 10, :passive, 3)
  end
  
  def basic_test_router_req(ip, port, cnt2, mode, size) do
    {s1, s2} = create_bound_pair_multi(:router, :req, cnt2, mode, ip, port)
    msg = String.duplicate("X", size)

    ## send a message for each client Socket and expect a result on each socket
    Enum.each(s2, fn(s) -> :ok = Exzmq.send(s, [msg]) end)
    Enum.each(s2, fn(_s) ->
                          {:ok, {id, [msg]}} = Exzmq.recv(s1)
                          :ok = Exzmq.send(s1, {id, [msg]})
                  end)
    Enum.each(s2, fn(s) -> {:ok, msg} = Exzmq.recv(s) end)

     :ok = Exzmq.close(s1)
    Enum.each(s2, fn(s) -> :ok = Exzmq.close(s) end)
  end
  
  test "basic tests router" do 
     basic_test_router_req({127,0,0,1}, 5561, 10, :passive, 3)
  end

  def basic_test_rep_req(ip, port, cnt2, mode, size) do
    {s1, s2} = create_bound_pair_multi(:rep, :req, cnt2, mode, ip, port)
    msg = String.duplicate("X", size)

    ## send a message for each client Socket and expect a result on each socket
    Enum.each(s2, fn(s) -> :ok = Exzmq.send(s, [msg]) end)
    Enum.each(s2, fn(_s) ->
                          {:ok, [msg]} = Exzmq.recv(s1)
                          :ok = Exzmq.send(s1, [msg])
                  end)
    Enum.each(s2, fn(s) -> {:ok, [msg]} = Exzmq.recv(s) end)

     :ok = Exzmq.close(s1)
    Enum.each(s2, fn(s) -> :ok = Exzmq.close(s) end)
  end

  test "basic_tests_rep_req" do
    basic_test_rep_req({127,0,0,1}, 5561, 10, :passive, 3)
  end

  def basic_test_pub_sub(ip, port, cnt2, mode, size) do
    {s1, s2} = create_bound_pair_multi(:pub, :sub, cnt2, mode, ip, port)
    msg = String.duplicate("X", size)

    ## receive a message for each client and expect a result on each socket
    {:error, :fsm} = Exzmq.recv(s1)
    :ok = Exzmq.send(s1, [msg])
    Enum.each(s2, fn(s) -> {:ok, [msg]} = Exzmq.recv(s) end)
    :ok = Exzmq.close(s1)
    Enum.each(s2, fn(s) -> :ok = Exzmq.close(s) end)
  end

  test "basic tests pub sub" do
    basic_test_pub_sub({127,0,0,1}, 5561, 10, :passive, 3)
  end
 
  test "shutdown stress test" do
    shutdown_stress_loop(10)
  end

  def shutdown_stress_loop(0), do: :ok

  def shutdown_stress_loop(n) do
    {:ok, s1} = Exzmq.socket([{:type, :rep}, {:active, false}])
    :ok = Exzmq.bind(s1, :tcp, 5558 + n, [])
    shutdown_stress_worker_loop(n, 100)
    :ok = join_procs(100)
    Exzmq.close(s1)
    shutdown_stress_loop(n-1)
  end

  test "shutdown no blocking test" do
    {:ok, s} = Exzmq.socket([{:type, :req}, {:active, false}])
    Exzmq.close(s)
  end

  def join_procs(0) do
    :ok
  end

  def join_procs(n) do
    receive do
        :proc_end ->
            join_procs(n-1)
    after
        2000 ->
            throw(:stuck)
    end
  end

  def shutdown_stress_worker_loop(_p, 0), do: :ok

  def shutdown_stress_worker_loop(p, n) do
    Process.spawn(__MODULE__, :worker, [self(), 5558 + p])
    shutdown_stress_worker_loop(p, n-1)
  end

  def worker(pid, port) do
    {:ok, s} = Exzmq.socket([{:type, :rep}, {:active, false}])
    :ok = Exzmq.connect(s, :tcp, {127,0,0,1}, port, [])
    :ok = Exzmq.close(s)
    send pid, :proc_end
  end

  def req_tcp_fragment_send(socket, data) do
    Enum.each(:erlang.binary_to_list(data), 
      fn(x) -> :gen_tcp.send(socket, <<x>>)
               :timer.sleep(10) 
      end)
  end

  test "open req socket and wait hello reply" do
      self = self()
      Process.spawn(fn() ->
                      {:ok,l} = :gen_tcp.listen(5555,[:binary, {:active, false}, {:packet, :raw}, {:reuseaddr, true}, {:nodelay, true}])
                      {:ok, s1} = :gen_tcp.accept(l)
                      req_tcp_fragment_send(s1, <<0x01,0x00>>)
                      {:ok, _} = :gen_tcp.recv(s1, 0)
                      send self, :connected
                      {:ok,<<_::[size(4),bytes],"ZZZ">>} = :gen_tcp.recv(s1, 0)
                      req_tcp_fragment_send(s1, <<0x01, 0x7F, 0x06, 0x7E, "Hello">>)
                      :gen_tcp.close(s1)
                      send self, :done
                    end)
      {:ok, s} = Exzmq.socket([{:type, :req}, {:active, false}])
      :ok = Exzmq.connect(s, :tcp, {127,0,0,1}, 5555, [{:timeout, 1000}])
      assert_receive :connected, 1000
      :ok = Exzmq.send(s, [<<"ZZZ">>])
      {:ok, [<<"Hello">>]} = Exzmq.recv(s)
      Exzmq.close(s)
  end

end       