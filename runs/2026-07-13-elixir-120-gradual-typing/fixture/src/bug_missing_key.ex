defmodule User do
  def name(map), do: Map.fetch!(map, :name)
end

defmodule CallsUser do
  def calls_name do
    User.name(%{})
  end
end
