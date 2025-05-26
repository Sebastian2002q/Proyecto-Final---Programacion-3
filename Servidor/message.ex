defmodule Message do
  defstruct sender: "", content: ""

  def crear(sender, content) do
    %Message{sender: sender, content: content}
  end
end
