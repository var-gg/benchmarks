defmodule BugDisjoint do
  def run(value) when is_integer(value) do
    value_or_error =
      if value > 1 do
        value
      else
        "not well"
      end

    Map.fetch!(value_or_error, :some_key)
  end
end
