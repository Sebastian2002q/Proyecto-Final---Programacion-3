defmodule User do
  defstruct user: "", password: ""

  def crear(user, password) do
    %User{user: user, password: password}
  end
end
