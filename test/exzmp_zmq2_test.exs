defmodule Exzmq.ZMQ3Test do
  use ExUnit.Case, async: false

  if System.get_env("ZMQ_TEST_SUITE") == "true" do

  def basic_tests_erlzmq(fun, transport, ip, port, type1, type2, mode, size) do
    basic_tests_erlzmq(fun, transport, ip, port, type1, [], type2, [], mode, size)
  end

  def basic_tests_erlzmq(fun, transport, ip, port, type1, id1, type2, id2, mode, size) do
    {:ok, c} = :erlzmq.context(1)
    {s1, s2} = create_bound_pair_erlzmq(c, type1, id1, type2, id2, mode, transport, ip, port)
    msg = String.duplicate("X", size)
    fun.({s1, s2}, msg, mode)
    ok = :erlzmq.close(s1)
    ok = Exzmq.close(s2)
    ok = :erlzmq.term(c)
  end
  
  def create_bound_pair_erlzmq(ctx, type1, id1, type2, id2, mode, transport, ip, port) do
    
  	active = true

    if mode == :passive do
      active = false
    end
    
    {:ok, s1} = :erlzmq.socket(ctx, [type1, {:active, active}])
    {:ok, s2} = Exzmq.socket([{:type, type2}, {:active, active}, {:identity,id2}])
    :ok = erlzmq_identity(S1, Id1)
    :ok = :erlzmq.bind(s1, transport)
    :ok = Exzmq.connect(s2, :tcp, ip, port, [])
    {S1, S2}
  end
  
  def erlzmq_identity(socket, []) do
    :ok
  end

  def erlzmq_identity(socket, id) do
    :erlzmq.setsockopt(socket, :identity, id)
  end

  test "reqrep_tcp_id_test_active" do
    basic_tests_erlzmq(&ping_pong_erlzmq/3, "tcp://127.0.0.1:5555", {127,0,0,1}, 5555, :req, "reqrep_tcp_id_test_active_req", :rep, "reqrep_tcp_id_test_active_rep", :active, 3)
    #basic_tests_ezmq(&ping_pong_ezmq/3, "tcp://127.0.0.1:5555", {127,0,0,1}, 5555, :req, "reqrep_tcp_id_test_active_req", :rep, "reqrep_tcp_id_test_active_rep", :active, 3)
  end

  def ping_pong_erlzmq({s1, s2}, msg, :active) do
    :ok = :erlzmq.send(s1, msg, [:sndmore])
    :ok = :erlzmq.send(s1, msg)
    assert_mbox({:zmq, s2, [msg,msg]})
    assert_mbox_empty()

    :ok = :ezmq.send(s2, [msg])
    assert_mbox({:zmq, s1, msg, []})

    :ok = :erlzmq.send(s1, msg)
    assert_mbox({:zmq, s2, [msg]})
    assert_mbox_empty()

    :ok = Exzmq.send(s2, [msg])
    assert_mbox({:zmq, s1, msg, []})
    assert_mbox_empty()

    :ok
   end

   ## assert that message queue is empty....
  def assert_mbox_empty() do
    receive do
       m -> assert false
	 after
	   0 -> :ok
	end
  end

  ## assert that top message in the queue is what we think it should be
  def assert_mbox(msg) do
    assert_mbox_match({msg,[],[:ok]})
  end

  def assert_mbox_match(match_spec) do
    compiled_match_spec = :ets.match_spec_compile([match_spec])
    receive do
      m -> case :ets.match_spec_run([m], compiled_match_spec) do
                [] -> assert false
                [ret] -> ret
           end
      after
       1000 ->
           assert false
    end
  end

  end

end