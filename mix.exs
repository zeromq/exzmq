defmodule Exzmp.Mixfile do
  use Mix.Project

  def project do
    [ app: :exzmq,
      version: "0.0.1",
      elixir: "~> 0.12.5",
      deps: deps ]
  end

  # Configuration for the OTP application
  def application do
    [
      mod: { Exzmq.App, [] },
      applications: [:sasl, :gen_listener_tcp]
    ]
  end

  # Returns the list of dependencies in the format:
  # { :foobar, git: "https://github.com/elixir-lang/foobar.git", tag: "0.1" }
  #
  # To specify particular versions, regardless of the tag, do:
  # { :barbat, "~> 0.1", github: "elixir-lang/barbat" }
  defp deps do
    [
      {:gen_listener_tcp, github: "travelping/gen_listener_tcp"}
    ]
  end
end
