defmodule Exzmp.Mixfile do
  use Mix.Project

  def project do
    [ app: :exzmq,
      version: "0.1.1",
      elixir: "~> 0.12.5",
      name: "Exzmp",
      source_url: "https://github.com/plemanach/exzmq",
      deps: deps ]
  end

  if System.get_env("ZMQ_TEST_SUITE") == "true" do
    # Configuration for the OTP application
    def application do
      [
        mod: { Exzmq.App, [] },
        applications: [:sasl, :gen_listener_tcp, :erlzmq]
      ]
    end
  else
    # Configuration for the OTP application
    def application do
      [
        mod: { Exzmq.App, [] },
        applications: [:sasl, :gen_listener_tcp]
      ]
    end
  end

  # Returns the list of dependencies in the format:
  # { :foobar, git: "https://github.com/elixir-lang/foobar.git", tag: "0.1" }
  #
  # To specify particular versions, regardless of the tag, do:
  # { :barbat, "~> 0.1", github: "elixir-lang/barbat" }
  if System.get_env("ZMQ_TEST_SUITE") == "true" do
    defp deps do
      [
        {:gen_listener_tcp, github: "kaos/gen_listener_tcp"},
        {:erlzmq, github: "zeromq/erlzmq2", tag: "2.1.11"}
      ]
    end
  else
    defp deps do
      [
        {:gen_listener_tcp, github: "kaos/gen_listener_tcp"},
      ]
    end
  end
end
