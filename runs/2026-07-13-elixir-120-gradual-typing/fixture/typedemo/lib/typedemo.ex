defmodule Typedemo do
  # Same missing-map-key shape as src/bug_missing_key.ex, but wrapped in a mix
  # project. `name/1` requires a map with a :name key; `boom/0` calls it with an
  # empty map, so the compiler's type checker emits the missing-key warning.
  # This is the module the mix exit-code demo compiles.
  def name(map), do: Map.fetch!(map, :name)
  def boom, do: name(%{})
end
