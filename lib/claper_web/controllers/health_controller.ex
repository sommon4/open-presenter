defmodule ClaperWeb.HealthController do
  @moduledoc """
  `GET /health` for load balancers and monitoring. Returns 200 when the
  application and the database answer, 503 otherwise.
  """
  use ClaperWeb, :controller

  def show(conn, _params) do
    database =
      try do
        case Claper.Repo.query("SELECT 1", [], timeout: 2_000) do
          {:ok, _} -> "ok"
          {:error, _} -> "error"
        end
      rescue
        _ -> "error"
      end

    status = if database == "ok", do: "ok", else: "degraded"

    conn
    |> put_status(if(status == "ok", do: 200, else: 503))
    |> json(%{
      status: status,
      database: database,
      version: Application.spec(:claper, :vsn) |> to_string(),
      time: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end
end
