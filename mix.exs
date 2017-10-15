## This Source Code Form is subject to the terms of the Mozilla Public
## License, v. 2.0. If a copy of the MPL was not distributed with this
## file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Exzmq.Mixfile do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :exzmq,
      version: @version,
      elixir: ">= 1.1.0",
      name: "Exzmq",
      package: package(),
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: [
        {:credo, "~> 0.2", only: [:dev, :test]}
      ],
      docs: [
        main: "Exzmq",
        source_ref: "v#{@version}",
        source_url: "https://github.com/zeromq/exzmq"
      ],
    ]
  end

  def application do
    [applications: []]
  end

  defp package do
    %{
      maintainers: [
        "Constantin Rack"
        ],
      licenses: ["Mozilla Public License 2.0"],
      links: %{
        "GitHub" => "https://github.com/zeromq/exzmq"
      }
    }
  end

end
