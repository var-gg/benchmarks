defmodule GradualEscape do
  def passthrough(x) do
    Map.fetch!(x, :any_key)
  end
end
