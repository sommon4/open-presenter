defmodule ClaperWeb.Office.OfficeApiTest do
  use ClaperWeb.ConnCase

  import Claper.{AccountsFixtures, EventsFixtures, PresentationsFixtures, PollsFixtures}
  import Claper.WordCloudsFixtures

  alias Claper.Office

  setup do
    user = user_fixture()
    event = event_fixture(%{user: user})
    pf = presentation_file_fixture(%{event: event, length: 5})
    presentation_state_fixture(%{presentation_file: pf})
    {:ok, plain, _token} = Office.create_token(user, "test")
    conn = build_conn() |> put_req_header("authorization", "Bearer #{plain}")
    %{user: user, event: event, pf: pf, conn: conn, plain: plain}
  end

  test "rejects missing or invalid tokens" do
    conn = get(build_conn(), ~p"/api/office/events")
    assert %{"error" => "unauthorized"} = json_response(conn, 401)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer claper_office_bad")
      |> get(~p"/api/office/events")

    assert json_response(conn, 401)
  end

  test "POST /auth/token returns identity and a socket token", %{conn: conn, user: user} do
    conn = post(conn, ~p"/api/office/auth/token")

    assert %{
             "data" => %{
               "user" => %{"email" => email},
               "socket_token" => socket_token,
               "socket_path" => "/office/socket",
               "scopes" => scopes
             }
           } = json_response(conn, 200)

    assert email == user.email
    assert "office:events:read" in scopes

    assert {:ok, %{user_id: uid}} =
             Phoenix.Token.verify(ClaperWeb.Endpoint, "office_socket", socket_token, max_age: 60)

    assert uid == user.id
  end

  test "GET /events lists the user's events", %{conn: conn, event: event} do
    conn = get(conn, ~p"/api/office/events")

    assert %{"data" => [%{"id" => uuid, "join_code" => code, "join_url" => url}]} =
             json_response(conn, 200)

    assert uuid == event.uuid
    assert code == String.upcase(event.code)
    assert url =~ "/e/#{event.code}"
  end

  test "GET /events/:id/interactions and /interactions/:id", %{conn: conn, event: event, pf: pf} do
    poll = poll_fixture(%{presentation_file_id: pf.id, position: 0})
    wc = word_cloud_fixture(%{presentation_file_id: pf.id, position: 1})

    conn1 = get(conn, ~p"/api/office/events/#{event.uuid}/interactions")

    assert %{"data" => [%{"id" => id1, "type" => "poll"}, %{"id" => id2, "type" => "word_cloud"}]} =
             json_response(conn1, 200)

    assert id1 == "poll_#{poll.id}"
    assert id2 == "word_cloud_#{wc.id}"

    conn2 = get(conn, ~p"/api/office/interactions/word_cloud_#{wc.id}")

    assert %{"data" => %{"title" => title, "results" => %{"words" => []}, "join_code" => _}} =
             json_response(conn2, 200)

    assert title == wc.title

    {:ok, _, _} = Claper.WordClouds.submit_response("a", event.uuid, wc, "Genetics")
    conn3 = get(conn, ~p"/api/office/interactions/word_cloud_#{wc.id}/results")

    assert %{"data" => %{"words" => [%{"text" => "Genetics", "count" => 1}]}} =
             json_response(conn3, 200)

    assert json_response(get(conn, ~p"/api/office/interactions/poll_999999"), 404)
  end

  test "GET /events/:id/state and /posts", %{conn: conn, event: event, pf: pf} do
    poll_fixture(%{presentation_file_id: pf.id, position: 0, enabled: true})
    conn1 = get(conn, ~p"/api/office/events/#{event.uuid}/state")

    assert %{
             "data" => %{
               "state" => %{"position" => 0},
               "active_interaction" => %{"type" => "poll"}
             }
           } =
             json_response(conn1, 200)

    Claper.PostsFixtures.post_fixture(%{event: event, body: "Why?"})
    conn2 = get(conn, ~p"/api/office/events/#{event.uuid}/posts?filter=questions")
    assert %{"data" => [%{"body" => "Why?"}]} = json_response(conn2, 200)
  end

  test "another user's event is not found", %{event: event} do
    {:ok, plain, _} = Office.create_token(user_fixture(), "other")

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{plain}")
      |> get(~p"/api/office/events/#{event.uuid}")

    assert json_response(conn, 404)
  end

  test "activate requires the write scope", %{conn: conn, user: user, pf: pf} do
    poll = poll_fixture(%{presentation_file_id: pf.id, position: 0, enabled: false})
    assert json_response(post(conn, ~p"/api/office/interactions/poll_#{poll.id}/activate"), 403)

    {:ok, plain, _} = Office.create_token(user, "rw", Office.Token.scopes())
    conn = build_conn() |> put_req_header("authorization", "Bearer #{plain}")

    assert %{"data" => %{"enabled" => true}} =
             json_response(post(conn, ~p"/api/office/interactions/poll_#{poll.id}/activate"), 200)

    assert %{"data" => %{"enabled" => false}} =
             json_response(
               post(conn, ~p"/api/office/interactions/poll_#{poll.id}/deactivate"),
               200
             )
  end
end
