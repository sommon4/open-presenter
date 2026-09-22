defmodule ClaperWeb.HealthControllerTest do
  use ClaperWeb.ConnCase

  test "reports ok when the database answers", %{conn: conn} do
    conn = get(conn, ~p"/health")
    assert %{"status" => "ok", "database" => "ok", "version" => _} = json_response(conn, 200)
  end
end
