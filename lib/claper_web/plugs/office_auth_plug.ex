defmodule ClaperWeb.Plugs.OfficeAuthPlug do
  @moduledoc """
  Authenticates Office API requests with a bearer token
  (`Authorization: Bearer claper_office_...`).

  Assigns `:office_token` and `:current_user`. Use
  `require_office_scope/2` in controllers to check scopes.
  """
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> plain] <- get_req_header(conn, "authorization"),
         {:ok, token} <- Claper.Office.verify_token(String.trim(plain)) do
      conn
      |> assign(:office_token, token)
      |> assign(:current_user, token.user)
    else
      _ ->
        conn
        |> put_status(401)
        |> put_resp_header("www-authenticate", ~s(Bearer realm="office"))
        |> json(%{error: "unauthorized", message: "A valid Office access token is required"})
        |> halt()
    end
  end

  @doc """
  Plug that halts with 403 when the token lacks `scope`.

      plug :require_office_scope, "office:interactions:read"
  """
  def require_office_scope(conn, scope) do
    if Claper.Office.has_scope?(conn.assigns.office_token, scope) do
      conn
    else
      conn
      |> put_status(403)
      |> json(%{error: "forbidden", message: "Token is missing the scope #{scope}"})
      |> halt()
    end
  end
end
