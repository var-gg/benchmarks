defmodule DeadClause do
  def classify(x) when is_integer(x) do
    cond do
      is_integer(x) -> :an_integer
      is_binary(x) -> :a_string
    end
  end
end
