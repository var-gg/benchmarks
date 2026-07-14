defmodule Typedemo.MixProject do
  use Mix.Project

  # Minimal mix project whose lib/typedemo.ex reproduces the missing-map-key
  # type warning. It exists only so run.sh can demonstrate the exit-code
  # semantics that a bare `elixirc` cannot: `mix compile` prints the warning
  # but exits 0, while `mix compile --warnings-as-errors` exits 1. No deps,
  # no network — `mix compile` runs fully offline.
  def project do
    [
      app: :typedemo,
      version: "0.1.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: []
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end
end
