defmodule ClaperWeb.Office.InteractionController do
  @moduledoc """
  Office API: one interaction and its live results.
  """
  use ClaperWeb, :controller

  import ClaperWeb.Plugs.OfficeAuthPlug, only: [require_office_scope: 2]

  alias Claper.Office
  alias Claper.Office.Serializer

  plug :require_office_scope, "office:interactions:read"
  plug :require_office_scope, "office:interactions:write" when action in [:activate, :deactivate]

  def show(%{assigns: %{current_user: user}} = conn, %{"id" => id}) do
    with {:ok, interaction, event} <- Office.get_interaction(user, id) do
      json(conn, %{data: Serializer.interaction(interaction, event)})
    else
      {:error, :not_found} -> not_found(conn)
    end
  end

  def results(%{assigns: %{current_user: user}} = conn, %{"id" => id}) do
    with {:ok, interaction, event} <- Office.get_interaction(user, id) do
      json(conn, %{data: Serializer.interaction(interaction, event).results})
    else
      {:error, :not_found} -> not_found(conn)
    end
  end

  def activate(conn, params), do: set_active(conn, params, true)
  def deactivate(conn, params), do: set_active(conn, params, false)

  defp set_active(%{assigns: %{current_user: user}} = conn, %{"id" => id}, active) do
    with {:ok, interaction, event} <- Office.get_interaction(user, id),
         {:ok, fresh} <- Office.set_active(interaction, event, active) do
      json(conn, %{data: Serializer.interaction(fresh, event)})
    else
      {:error, :not_found} -> not_found(conn)
      {:error, _} -> conn |> put_status(422) |> json(%{error: "unprocessable"})
    end
  end

  defp not_found(conn) do
    conn |> put_status(404) |> json(%{error: "not_found"})
  end
end
