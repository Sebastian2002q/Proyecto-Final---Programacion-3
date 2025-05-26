defmodule Room do
  defstruct user_property: "", name: "",users: [], messages: []

  def crear(user_property, name, users, messages) do
    %Room{user_property: user_property, name: name, users: users, messages: messages}
  end
end
