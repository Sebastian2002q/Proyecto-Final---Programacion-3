defmodule Servidor do
  @gestor_usuarios :gestor_usuarios
  @gestor_salas :gestor_salas
  @gestor_estado :gestor_estado

  defstruct users: [], rooms: [], logged_users: [], suscriptores_salas: %{}

  def main() do
    registrar_servicio(@gestor_estado, :estado)
    registrar_servicio(@gestor_usuarios, :gestor_usuarios)
    registrar_servicio(@gestor_salas, :gestor_salas)

    :timer.sleep(:infinity)
  end

  # Funciones para registrar los servicios del servidor
  defp registrar_servicio(nombre_servicio, :estado) do
    estado_inicial =
      case cargar_estado("estado_servidor.bin") do
        nil -> %Servidor{}
        estado -> estado
      end

    pid = spawn(fn -> loop_estado(estado_inicial) end)

    Process.register(pid, nombre_servicio)
  end

  defp registrar_servicio(nombre_servicio, tipo) do
    pid = spawn(fn -> loop(tipo) end)
    Process.register(pid, nombre_servicio)
  end

  # Función que recibe y reenvia la respuesta
  defp recibir_y_reenviar_respuesta(destino) do
    receive do
      respuesta -> send(destino, respuesta)
    end
  end

  # Loop para la gestión del servicio :gestor_estado y mantener control del estado de la instancia del servidor
  defp loop_estado(estado) do
    "Servidor escuchando..."
    |> Util.mostrar_mensaje()

    receive do
      {productor, {user, pass, :register}} ->
        case add_user(estado, user, pass) do
          {:ok, nuevo_estado} ->
            send(productor, :ok)
            loop_estado(nuevo_estado)

          :error ->
            send(productor, :error)
            loop_estado(estado)
        end

      {productor, {user, pass, :login}} ->
        case login(estado, user, pass) do
          {:ok, nuevo_estado} ->
            send(productor, {:ok, user})
            loop_estado(nuevo_estado)

          :error ->
            send(productor, :error)
            loop_estado(estado)
        end

      {productor, :list} ->
        case list_logged_users(estado) do
          {:ok, list_logged_users} ->
            send(productor, {:ok, list_logged_users})
            loop_estado(estado)

          :error ->
            send(productor, :error)
            loop_estado(estado)
        end

      {productor, :list_created_room} ->
        case list_created_rooms(estado) do
          {:ok, rooms} ->
            send(productor, {:ok, rooms})
            loop_estado(estado)

          :error ->
            send(productor, :error)
            loop_estado(estado)
        end

      {productor, {user_property, room, :create}} ->
        case create_room(estado, user_property, room) do
          {:ok, nuevo_estado} ->
            send(productor, {:ok, user_property})
            loop_estado(nuevo_estado)

          :error ->
            send(productor, {:error, user_property})
            loop_estado(estado)
        end

      {productor, {user, room, :join}} ->
        case join_room(estado, user, room) do
          {:ok, nuevo_estado} ->
            send(productor, :ok)
            loop_estado(nuevo_estado)

          :error ->
            send(productor, :error)
            loop_estado(estado)
        end

      {productor, {room, :get_messages}} ->
        case get_messages_room(estado, room) do
          {:ok, messages} ->
            send(productor, {:ok, messages})
            loop_estado(estado)

          :error ->
            send(productor, :error)
            loop_estado(estado)
        end

      {productor, {user, room, message, :send_message}} ->
        case send_message_room(estado, user, room, message) do
          {:ok, nuevo_estado} ->
            send(productor, :ok)
            loop_estado(nuevo_estado)

          :error ->
            send(productor, :error)
            loop_estado(estado)
        end

      {productor, {user, name, pid, :suscribirse}} ->
        case suscribir_usuario(estado, user, name, pid) do
          {:ok, nuevo_estado} ->
            send(productor, :ok)
            loop_estado(nuevo_estado)

          :error ->
            send(productor, :error)
            loop_estado(estado)
        end

      {productor, {user, room, :exit_room}} ->
        case exit_room(estado, user, room) do
          {:ok, nuevo_estado} ->
            send(productor, :ok)
            loop_estado(nuevo_estado)

          :error ->
            send(productor, :error)
            loop_estado(estado)
        end

      {productor, {user, :exit_session}} ->
        case exit_session(estado, user) do
          {:ok, nuevo_estado} ->
            send(productor, :ok)
            loop_estado(nuevo_estado)

          :error ->
            send(productor, :error)
            loop_estado(estado)
        end

      :save ->
        guardar_estado(estado)
        System.halt()

      _ ->
        Util.mostrar_error("Mensaje no reconocido")
        loop_estado(estado)
    end
  end

  # Loop para la gestión del servicio :gestor_usuarios
  defp loop(:gestor_usuarios) do
    receive do
      {productor, {user, pass, :register}} ->
        send(@gestor_estado, {self(), {user, pass, :register}})
        recibir_y_reenviar_respuesta(productor)
        loop(@gestor_usuarios)

      {productor, {user, pass, :login}} ->
        send(@gestor_estado, {self(), {user, pass, :login}})
        recibir_y_reenviar_respuesta(productor)
        loop(@gestor_usuarios)

      {productor, :list} ->
        send(@gestor_estado, {self(), :list})
        recibir_y_reenviar_respuesta(productor)
        loop(@gestor_usuarios)

      {productor, {user, :exit_session}} ->
        send(@gestor_estado, {self(), {user, :exit_session}})
        recibir_y_reenviar_respuesta(productor)
        loop(@gestor_usuarios)

      _ ->
        Util.mostrar_error("Mensaje no reconocido")
        loop(@gestor_usuarios)
    end
  end

  # Loop para la gestión del servicio :gestor_salas
  defp loop(:gestor_salas) do
    receive do
      {productor, :list_created_room} ->
        send(@gestor_estado, {self(), :list_created_room})
        recibir_y_reenviar_respuesta(productor)
        loop(@gestor_salas)

      {productor, {user_property, room, :create}} ->
        send(@gestor_estado, {self(), {user_property, room, :create}})
        recibir_y_reenviar_respuesta(productor)
        loop(@gestor_salas)

      {productor, {user, room, :join}} ->
        send(@gestor_estado, {self(), {user, room, :join}})
        recibir_y_reenviar_respuesta(productor)
        loop(@gestor_salas)

      {productor, {room_name, :get_messages}} ->
        send(@gestor_estado, {self(), {room_name, :get_messages}})
        recibir_y_reenviar_respuesta(productor)
        loop(@gestor_salas)

      {productor, {user, room, message, :send_message}} ->
        send(@gestor_estado, {self(), {user, room, message, :send_message}})
        recibir_y_reenviar_respuesta(productor)
        loop(@gestor_salas)

      {productor, {user, name, pid, :suscribirse}} ->
        send(@gestor_estado, {self(), {user, name, pid, :suscribirse}})
        recibir_y_reenviar_respuesta(productor)
        loop(@gestor_salas)

      {productor, {user, room, :exit_room}} ->
        send(@gestor_estado, {self(), {user, room, :exit_room}})
        recibir_y_reenviar_respuesta(productor)
        loop(@gestor_salas)

      _ ->
        Util.mostrar_error("Mensaje no reconocido")
        loop(@gestor_salas)
    end
  end

  # Función que recibe un nuevo usuario, comprueba si existe algún otro usuario con el mismo usar_name, sino existe lo registra
  defp add_user(%Servidor{users: users} = servidor, new_user, new_password) do
    IO.inspect(users, label: "Usuarios actuales")

    if Enum.any?(users, fn %User{user: user} -> user == new_user end) do
      Util.mostrar_error("El nombre de usuario ya existe")
      :error
    else
      update_users = [User.crear(new_user, new_password) | users]
      nuevo_estado = %Servidor{servidor | users: update_users}
      IO.inspect(nuevo_estado.users, label: "Usuarios actuales")
      {:ok, nuevo_estado}
    end
  end

  # Función que recibe las credenciales de un usuario, comprueba si está dentro de la instancia del servidor, si está, lo agrega a logged_users
  defp login(%Servidor{users: users, logged_users: logged_users} = server, user, password) do
    case Enum.find(users, fn %User{user: u, password: p} -> u == user and p == password end) do
      nil ->
        Util.mostrar_error("Usuario o contraseña incorrectos")
        :error

      _ ->
        Util.mostrar_mensaje("Inicio de sesión exitoso")

        update_logged_users =
          if user in logged_users do
            logged_users
          else
            [user | logged_users]
          end

        nuevo_estado = %Servidor{server | logged_users: update_logged_users}
        {:ok, nuevo_estado}
    end
  end

  # Función que retorna la lista de los usuarios conectados
  defp list_logged_users(%Servidor{logged_users: logged_users}) do
    if Enum.empty?(logged_users) do
      :error
    else
      {:ok, logged_users}
    end
  end

  # Función que recibe una nueva sala y su propietario, comprueba si existe alguna sala con el mismo nombre, sino existe, la crea
  defp create_room(%Servidor{rooms: rooms} = servidor, user_property, room) do
    if Enum.any?(rooms, fn %Room{name: name} -> name == room end) do
      Util.mostrar_error("Ya existe una sala con ese nombre")
      :error
    else
      update_rooms = [%Room{user_property: user_property, name: room} | rooms]
      nuevo_estado = %Servidor{servidor | rooms: update_rooms}
      IO.inspect(nuevo_estado.rooms, label: "Rooms actuales")
      {:ok, nuevo_estado}
    end
  end

  # Función que recibe el nombre de una sala y un usuario, comprueba si la sala existe, si existe, comprueba si dicho usuario ya se encuentra dentro de la sala, sino está dentro de la sala, lo agrega
  defp join_room(
         %Servidor{rooms: rooms} = servidor,
         user,
         room_name
       ) do
    case Enum.find(rooms, fn %Room{name: name} -> name == room_name end) do
      nil ->
        Util.mostrar_error("La sala '#{room_name}' no existe")
        :error

      %Room{users: users} = room ->
        new_users = if user in users, do: users, else: [user | users]

        new_room = %Room{room | users: new_users}

        new_rooms =
          Enum.map(rooms, fn
            %Room{name: ^room_name} -> new_room
            other -> other
          end)

        nuevo_estado = %Servidor{servidor | rooms: new_rooms}
        Util.mostrar_mensaje("#{user} se ha unido a la sala '#{room_name}'")
        {:ok, nuevo_estado}
    end
  end

  # Función que retorna la lista de salas existentes
  defp list_created_rooms(%Servidor{rooms: rooms}) do
    if Enum.empty?(rooms) do
      :error
    else
      flat_rooms = Enum.map(rooms, &Map.from_struct/1)
      {:ok, flat_rooms}
    end
  end

  # Función que retorna los mensajes de una sala
  defp get_messages_room(%Servidor{rooms: rooms}, room_name) do
    case Enum.find(rooms, fn %Room{name: name} -> name == room_name end) do
      nil -> :error
      %Room{messages: messages} -> {:ok, messages}
    end
  end

  # Función para enviar un mensaje
  defp send_message_room(
         %Servidor{rooms: rooms, suscriptores_salas: subs} = servidor,
         user,
         room,
         message
       ) do
    case Enum.find(rooms, fn %Room{name: name} -> name == room end) do
      nil ->
        :error

      %Room{messages: messages} = found_room ->
        new_message = %Message{sender: user, content: message}
        updated_room = %Room{found_room | messages: messages ++ [new_message]}

        updated_rooms =
          Enum.map(rooms, fn
            %Room{name: ^room} -> updated_room
            other -> other
          end)

        Enum.each(Map.get(subs, room, []), fn {_, pid} ->
          send(pid, new_message)
        end)

        nuevo_estado = %Servidor{servidor | rooms: updated_rooms}
        {:ok, nuevo_estado}
    end
  end

  # Función para suscribir un usuario a una sala con su pid y su username
  defp suscribir_usuario(
         %Servidor{rooms: rooms, suscriptores_salas: subs} = servidor,
         user,
         room_name,
         pid
       ) do
    case Enum.find(rooms, fn %Room{name: name} -> name == room_name end) do
      nil ->
        Util.mostrar_error("La sala '#{room_name}' no existe")
        :error

      %Room{} ->
        new_subs =
          Map.update(subs, room_name, [{user, pid}], fn lista ->
            if Enum.any?(lista, fn {_, p} -> p == pid end) do
              lista
            else
              [{user, pid} | lista]
            end
          end)

        nuevo_estado = %Servidor{servidor | suscriptores_salas: new_subs}
        {:ok, nuevo_estado}
    end
  end

  # Función para salir de una sala
  defp exit_room(%Servidor{rooms: rooms, suscriptores_salas: subs} = servidor, user, room_name) do
    case Enum.find(rooms, fn %Room{name: name} -> name == room_name end) do
      nil ->
        :error

      %Room{name: ^room_name, users: users} = found_room ->
        updated_users = Enum.reject(users, fn u -> u == user end)
        updated_room = %Room{found_room | users: updated_users}

        updated_rooms =
          Enum.map(rooms, fn
            %Room{name: ^room_name} -> updated_room
            other -> other
          end)

        updated_subs =
          Map.update(subs, room_name, [], fn lista ->
            Enum.reject(lista, fn {u, _pid} -> u == user end)
          end)

        nuevo_estado = %Servidor{
          servidor
          | rooms: updated_rooms,
            suscriptores_salas: updated_subs
        }

        {:ok, nuevo_estado}
    end
  end

  # Función para cerrar sesión
  defp exit_session(%Servidor{logged_users: logged_users} = servidor, user) do
    if user in logged_users do
      nuevo_logged_users = Enum.reject(logged_users, fn u -> u == user end)
      nuevo_estado = %Servidor{servidor | logged_users: nuevo_logged_users}
      {:ok, nuevo_estado}
    else
      :error
    end
  end

  # Persistencia
  defp guardar_estado(estado) do
    binario = :erlang.term_to_binary(estado)
    File.write("estado_servidor.bin", binario)
  end

  defp cargar_estado(archivo) do
    case File.read(archivo) do
      {:ok, binario} -> :erlang.binary_to_term(binario)
      {:error, _} -> nil
    end
  end
end

Servidor.main()
