defmodule ClaperWeb.OfficeSocket do
  @moduledoc """
  Realtime socket for the PowerPoint add-in. Connect with the `socket_token`
  returned by `POST /api/office/auth/token`.
  """
  use Phoenix.Socket

  channel "interaction:*", ClaperWeb.OfficeChannel
  channel "event:*", ClaperWeb.OfficeChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    with {:ok, %{user_id: user_id, token_id: token_id}} <-
           Phoenix.Token.verify(ClaperWeb.Endpoint, "office_socket", token,
             max_age: ClaperWeb.Office.AuthController.socket_token_max_age()
           ),
         %Claper.Office.Token{user_id: ^user_id} = office_token <-
           Claper.Repo.get(Claper.Office.Token, token_id) |> Claper.Repo.preload(:user) do
      {:ok, socket |> assign(:user, office_token.user) |> assign(:office_token, office_token)}
    else
      _ -> :error
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(socket), do: "office_socket:#{socket.assigns.office_token.id}"
end
