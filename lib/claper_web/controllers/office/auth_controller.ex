defmodule ClaperWeb.Office.AuthController do
  @moduledoc """
  Office API: validates a token and returns the identity and a short-lived
  socket token for the realtime channel.
  """
  use ClaperWeb, :controller

  @socket_token_max_age 60 * 60 * 12

  def token(%{assigns: %{current_user: user, office_token: token}} = conn, _params) do
    socket_token =
      Phoenix.Token.sign(ClaperWeb.Endpoint, "office_socket", %{
        user_id: user.id,
        token_id: token.id
      })

    json(conn, %{
      data: %{
        user: %{id: user.id, email: user.email},
        token_name: token.name,
        scopes: token.scopes,
        socket_token: socket_token,
        socket_token_expires_in: @socket_token_max_age,
        socket_path: "/office/socket"
      }
    })
  end

  def socket_token_max_age, do: @socket_token_max_age
end
