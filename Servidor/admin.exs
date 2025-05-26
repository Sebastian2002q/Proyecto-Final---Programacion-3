defmodule Admin do
  @nodo_remoto :nodoservidor@localhost
  @servicio_remoto_gestor_estado {:gestor_estado, @nodo_remoto}

  def main() do
    establecer_conexion(@nodo_remoto)
    |> proceso_deseado()
  end

  defp proceso_deseado(false) do
    "No se pudo conectar con el servidor"
    |> Util.mostrar_mensaje()
  end

  defp proceso_deseado(true) do
    x =
      "\n/save\n"
      |> Util.ingresar(:texto)

    case x do
      "/save" ->
        save()
      _ ->
        Util.mostrar_error("Error, por favor ingrese uno de los comandos listados")
        proceso_deseado(true)
    end
  end

  defp save() do
    send(@servicio_remoto_gestor_estado, :save)
  end

  defp establecer_conexion(nodo_remoto) do
    Node.connect(nodo_remoto)
  end
end

Admin.main()
