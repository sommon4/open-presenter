defmodule ClaperWeb.Office.EventController do
  @moduledoc """
  Office API: events the token's user can present.
  """
  use ClaperWeb, :controller

  import ClaperWeb.Plugs.OfficeAuthPlug, only: [require_office_scope: 2]

  alias Claper.Office
  alias Claper.Office.Serializer

  plug :require_office_scope, "office:events:read"

  def index(%{assigns: %{current_user: user}} = conn, _params) do
    events = Office.list_events(user) |> Enum.map(&Serializer.event/1)
    json(conn, %{data: events})
  end

  def show(%{assigns: %{current_user: user}} = conn, %{"id" => uuid}) do
    case Office.get_event(user, uuid) do
      {:ok, event} -> json(conn, %{data: Serializer.event(event)})
      {:error, :not_found} -> not_found(conn)
    end
  end

  def interactions(%{assigns: %{current_user: user}} = conn, %{"id" => uuid}) do
    with {:ok, event} <- Office.get_event(user, uuid) do
      data =
        event
        |> Office.list_interactions()
        |> Enum.map(&Serializer.interaction(&1, event))

      json(conn, %{data: data})
    else
      {:error, :not_found} -> not_found(conn)
    end
  end

  def state(%{assigns: %{current_user: user}} = conn, %{"id" => uuid}) do
    with {:ok, event} <- Office.get_event(user, uuid) do
      state = event.presentation_file.presentation_state

      active =
        state && Claper.Interactions.get_active_interaction(event, state.position)

      json(conn, %{
        data: %{
          state: state && Serializer.state(state),
          active_interaction: active && Serializer.interaction(active, event)
        }
      })
    else
      {:error, :not_found} -> not_found(conn)
    end
  end

  def posts(%{assigns: %{current_user: user}} = conn, %{"id" => uuid} = params) do
    with {:ok, event} <- Office.get_event(user, uuid) do
      posts =
        case params["filter"] do
          "pinned" -> Claper.Posts.list_pinned_posts(event.uuid)
          "questions" -> Claper.Posts.list_questions(event.uuid, [], :likes)
          _ -> Claper.Posts.list_posts(event.uuid)
        end

      json(conn, %{data: Enum.map(posts, &Serializer.post/1)})
    else
      {:error, :not_found} -> not_found(conn)
    end
  end

  defp not_found(conn) do
    conn |> put_status(404) |> json(%{error: "not_found"})
  end
end
