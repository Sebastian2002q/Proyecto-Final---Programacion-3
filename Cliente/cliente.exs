defmodule Cliente do
  @nodo_remoto :nodoservidor@localhost
  @servicio_remoto_gestor_usuarios {:gestor_usuarios, @nodo_remoto}
  @servicio_remoto_gestor_salas {:gestor_salas, @nodo_remoto}

  def main() do
    "Bienvenido"
    |> Util.mostrar_mensaje()

    establecer_conexion(@nodo_remoto)
    |> proceso_deseado()
  end

  # Función que establece la conexión con el servidor
  defp establecer_conexion(nodo_remoto) do
    Node.connect(nodo_remoto)
  end

  # Función que envía mensajes a uno de los servicios del servidor
  defp enviar_mensaje(servicio, mensaje) do
    send(servicio, {self(), mensaje})
  end

  # Funciones para mostrar en consola los procesos permitidos antes de entrar al chat
  defp proceso_deseado(false) do
    "No se pudo conectar con el servidor"
    |> Util.mostrar_mensaje()
  end

  defp proceso_deseado(true) do
    x =
      "\n/login (Iniciar sesión) \n/register (Registrarse)\n"
      |> Util.ingresar(:texto)

    case x do
      "/login" ->
        login()

      "/register" ->
        register()

      _ ->
        Util.mostrar_error("Error, por favor ingrese uno de los comandos listados")
        proceso_deseado(true)
    end
  end

  # Función para mostrar en consola los procesos permitidos después de hacer login
  defp proceso_deseado(user) do
    "\nLista de comandos:\n/list (Mostrar usuarios conectados)\n/join (Unirse a una sala de chat)\n/create (Crear una nueva sala de chat)\n/history (Consultar historial de mensajes)\n/exit (Salir del chat)"
    |> Util.mostrar_mensaje()

    x =
      "¿Que desea hacer?: "
      |> Util.ingresar(:texto)

    case x do
      "/list" ->
        list(user)

      "/join" ->
        list_created_room(user)

      "/create" ->
        create_room(user)

      "/history" ->
        history(user)

      "/exit" ->
        exit_session(user)

      _ ->
        Util.mostrar_error("Error, por favor ingrese uno de los comandos listados\n")
        proceso_deseado(user)
    end
  end

  # Función para mostrar en consola los procesos permitidos una vez ingresado a una sala
  defp proceso_deseado_room(user, room) do
    x = Util.ingresar("", :texto)

    case x do
      "/send" ->
        send_message(user, room)

      "/exit" ->
        exit_room(user, room)

      _ ->
        Util.mostrar_error("Comando no reconocido, por favor use uno de los comandos permitidos")
        proceso_deseado_room(user, room)
    end
  end

  # Función para registrarse en el chat
  defp register() do
    user =
      "Ingrese el nombre de usuario: "
      |> Util.ingresar(:texto)

    pass =
      "Ingrese la contraseña: "
      |> Util.ingresar(:texto)

    enviar_mensaje(@servicio_remoto_gestor_usuarios, {user, pass, :register})
    recibir_respuesta(:register)
  end

  # Función para entrar al chat
  defp login() do
    user =
      "Ingrese el nombre de usuario: "
      |> Util.ingresar(:texto)

    pass =
      "Ingrese la contraseña: "
      |> Util.ingresar(:texto)

    enviar_mensaje(@servicio_remoto_gestor_usuarios, {user, pass, :login})
    recibir_respuesta(:login)
  end

  # Función del comando /list, muestra los usuarios conectados
  defp list(user) do
    enviar_mensaje(@servicio_remoto_gestor_usuarios, :list)
    recibir_respuesta(user, :list)
    proceso_deseado(user)
  end

  # Función del comando /join, permite ingresar a una sala
  defp join_room(user) do
    name =
      "Ingrese el nombre de la sala a la que desea entrar: "
      |> Util.ingresar(:texto)

    enviar_mensaje(@servicio_remoto_gestor_salas, {user, name, :join})
    recibir_respuesta(user, name, :join)
  end

  # Función del comando /create, permite crear una sala
  defp create_room(user) do
    name =
      "Ingrese el nombre de la sala= "
      |> Util.ingresar(:texto)

    enviar_mensaje(@servicio_remoto_gestor_salas, {user, name, :create})
    recibir_respuesta(user, :create)
  end

  # Función para ver las salas creadas
  defp list_created_room(user) do
    enviar_mensaje(@servicio_remoto_gestor_salas, :list_created_room)
    recibir_respuesta(user, :list_created_room)
  end

  # Función para cargar los mensajes enviador en la sala
  defp mostrar_sala(user, name) do
    enviar_mensaje(@servicio_remoto_gestor_salas, {name, :get_messages})
    recibir_respuesta(user, name, :get_messages)
  end

  # Función para enviar un mensaje
  defp send_message(user, room) do
    message = Util.ingresar("", :texto)
    enviar_mensaje(@servicio_remoto_gestor_salas, {user, room, message, :send_message})
    recibir_respuesta(user, room, :send_message)
  end

  # Función para ver los mensajes de una sala en específico
  defp history(user) do
    enviar_mensaje(@servicio_remoto_gestor_salas, :list_created_room)
    recibir_respuesta(user, :history)
  end

  # Función para salir de una sala
  defp exit_room(user, room) do
    enviar_mensaje(@servicio_remoto_gestor_salas, {user, room, :exit_room})
    recibir_respuesta(user, :exit_room)
  end

  # Función para salir del chat
  defp exit_session(user) do
    enviar_mensaje(@servicio_remoto_gestor_usuarios, {user, :exit_session})
    recibir_respuesta(:exit_session)
  end

  # Funciones para recibir y gestionar las respuestas del servidor
  defp recibir_respuesta(:register) do
    receive do
      :ok ->
        "Usuario creado correctamente"
        |> Util.mostrar_mensaje()

        proceso_deseado(true)

      :error ->
        "El nombre de usuario ya existe"
        |> Util.mostrar_mensaje()

        register()
    after
      5_000 ->
        Util.mostrar_error("Sin respuesta del servidor. Intente de nuevo.")
        proceso_deseado(true)
    end
  end

  defp recibir_respuesta(:login) do
    receive do
      {:ok, user} ->
        "\nInicio de sesión exitoso\n"
        |> Util.mostrar_mensaje()

        "Bienvenido #{user} \n"
        |> Util.mostrar_mensaje()

        proceso_deseado(user)

      :error ->
        "Usuario o contraseña incorrectos"
        |> Util.mostrar_mensaje()

        login()
    after
      5_000 ->
        Util.mostrar_error("Sin respuesta del servidor. Intente de nuevo.")
        proceso_deseado(true)
    end
  end

  defp recibir_respuesta(user, :list) do
    receive do
      {:ok, list_logged_users} ->
        "\nUsuarios conectados:"
        |> Util.mostrar_mensaje()

        Enum.each(list_logged_users, fn user ->
          "- #{user}" |> Util.mostrar_mensaje()
        end)

        Util.mostrar_mensaje("\n")

      :error ->
        Util.mostrar_error("Aún no hay nadie conectado")
    after
      5_000 ->
        Util.mostrar_error("Sin respuesta del servidor. Intente de nuevo.")
        proceso_deseado(user)
    end
  end

  defp recibir_respuesta(user, :list_created_room) do
    receive do
      {:ok, rooms} ->
        Util.mostrar_mensaje("\nSalas: ")
        Enum.each(rooms, fn %{name: name} -> "- #{name}" |> Util.mostrar_mensaje() end)
        join_room(user)

      :error ->
        Util.mostrar_mensaje("\nAún no se ha creado ninguna sala, usa /create para crear una\n")
        proceso_deseado(user)
    after
      5_000 ->
        Util.mostrar_error("Sin respuesta del servidor. Intente de nuevo.")
        proceso_deseado(user)
    end
  end

  defp recibir_respuesta(user, :history) do
    receive do
      {:ok, rooms} ->
        Util.mostrar_mensaje("\nSalas: ")
        Enum.each(rooms, fn %{name: name} -> "- #{name}" |> Util.mostrar_mensaje() end)
        name = "\nIngrese el nombre de la sala que desea ver los mensajes: "
        |> Util.ingresar(:texto)
        enviar_mensaje(@servicio_remoto_gestor_salas, {name, :get_messages})
        recibir_respuesta(user, name, :history_messages)

      :error ->
        Util.mostrar_mensaje("\nAún no se ha creado ninguna sala, usa /create para crear una\n")
        proceso_deseado(user)
    after
      5_000 ->
        Util.mostrar_error("Sin respuesta del servidor. Intente de nuevo.")
        proceso_deseado(user)
    end
  end

  defp recibir_respuesta(user, name, :history_messages) do
    receive do
      {:ok, messages} ->
        Util.mostrar_mensaje("Sala: #{name}")
        Enum.each(messages, fn m -> "- #{m.sender}: #{m.content}" |> Util.mostrar_mensaje() end)
        proceso_deseado(user)

      :error ->
        Util.mostrar_mensaje("Aún no se ha enviado ningún mensaje.")
        proceso_deseado(user)
    after
      5_000 ->
        Util.mostrar_error("Sin respuesta del servidor. Intente de nuevo.")
        proceso_deseado(user)
    end
  end

  defp recibir_respuesta(user, name, :join) do
    receive do
      :ok ->
        escuchar_mensajes(user, name)
        Util.mostrar_mensaje("Te uniste satisfactoriamente a la sala\n")
        Util.mostrar_mensaje("Sala: #{name}")

        Util.mostrar_mensaje(
          "Lista de comandos: \n/send (envía un mensaje)\n/exit (salir de la sala)"
        )

        mostrar_sala(user, name)

      :error ->
        Util.mostrar_mensaje(
          "Estás intentando entrar a una sala que no existe, por favor ingresa el nombre de una sala existente"
        )

        join_room(user)
    after
      5_000 ->
        Util.mostrar_error("Sin respuesta del servidor. Intente de nuevo.")
        proceso_deseado(user)
    end
  end

  defp recibir_respuesta(user, :create) do
    receive do
      {:ok, user_property} ->
        Util.mostrar_mensaje("\nSala creada correctamente\n")
        proceso_deseado(user_property)

      {:error, user_property} ->
        Util.mostrar_mensaje("Ya existe una sala con ese nombre de usuario")
        create_room(user_property)
    after
      5_000 ->
        Util.mostrar_error("Sin respuesta del servidor. Intente de nuevo.")
        proceso_deseado(user)
    end
  end

  defp recibir_respuesta(user, name, :get_messages) do
    receive do
      {:ok, messages} ->
        Enum.each(messages, fn m -> "- #{m.sender}: #{m.content}" |> Util.mostrar_mensaje() end)
        proceso_deseado_room(user, name)

      :error ->
        Util.mostrar_mensaje("Aún no se ha enviado ningún mensaje.")
        proceso_deseado_room(user, name)
    after
      5_000 ->
        Util.mostrar_error("Sin respuesta del servidor. Intente de nuevo.")
        proceso_deseado(user)
    end
  end

  defp recibir_respuesta(user, room, :send_message) do
    receive do
      :ok ->
        proceso_deseado_room(user, room)

      :error ->
        Util.mostrar_error("Error")
    after
      5_000 ->
        Util.mostrar_error("Sin respuesta del servidor. Intente de nuevo.")
        proceso_deseado(user)
    end
  end

  defp recibir_respuesta(user, :suscribirse) do
    receive do
      :ok ->
        :ok

      :error ->
        :error
    after
      5_000 ->
        Util.mostrar_error("Sin respuesta del servidor. Intente de nuevo.")
        proceso_deseado(user)
    end
  end

  defp recibir_respuesta(user, :exit_room) do
    receive do
      :ok ->
        proceso_deseado(user)

      :error ->
        :error
    after
      5_000 ->
        Util.mostrar_error("Sin respuesta del servidor. Intente de nuevo.")
        proceso_deseado(user)
    end
  end

  defp recibir_respuesta(:exit_session) do
    receive do
      :ok ->
        proceso_deseado(true)

      :error ->
        :error
    after
      5_000 ->
        Util.mostrar_error("Sin respuesta del servidor. Intente de nuevo.")
        proceso_deseado(true)
    end
  end

  # Proceso paralelo para escuchar los mensajes enviados por otros usuarios o por uno mismo
  defp escuchar_mensajes(user, name) do
    spawn(fn ->
      pid = self()
      enviar_mensaje(@servicio_remoto_gestor_salas, {user, name, pid, :suscribirse})
      recibir_respuesta(user, :suscribirse)
      loop_escucha()
    end)
  end

  defp loop_escucha() do
    receive do
      new_message ->
        Util.mostrar_mensaje("- #{new_message.sender}: #{new_message.content}")
        loop_escucha()
    end
  end
end

Cliente.main()
