defmodule Util do
  def mostrar_mensaje(mensaje) do
    mensaje
    |> IO.puts()
  end

  def ingresar(mensaje, :texto) do
    mensaje
    |> IO.gets()
    |> String.trim()
  end

  def ingresar(mensaje, :boolean) do
    valor =
      mensaje
      |> ingresar(:texto)
      |> String.downcase()

      Enum.member?(["si","sí","s"],valor)
  end

  def ingresar(mensaje, :real), do: ingresar(mensaje, &String.to_float/1, :real)
  def ingresar(mensaje, :entero), do: ingresar(mensaje, &String.to_integer/1, :entero)

  defp ingresar(mensaje, parser, tipo_dato) do
    try do
      mensaje
      |> ingresar(:texto)
      |> parser.()
    rescue
      ArgumentError ->
        "Error, se espera que ingrese un número #{tipo_dato}\n"
        |> mostrar_error()

        mensaje
        |> ingresar(parser, tipo_dato)
    end
  end

  def mostrar_error(mensaje) do
    IO.puts(:standard_error, mensaje)
  end
end
