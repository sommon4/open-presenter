defmodule ClaperWeb.UserSettingsLive.OfficeTokenTest do
  use ClaperWeb.ConnCase

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  test "generates, shows once and revokes a PowerPoint token", %{conn: conn, user: user} do
    {:ok, live, html} = live(conn, ~p"/users/settings")
    assert html =~ "PowerPoint add-in"

    html =
      live
      |> form("#office-integration form", %{"name" => "Laptop", "write" => "true"})
      |> render_submit()

    assert html =~ "claper_office_"
    assert has_element?(live, "#new-office-token")
    assert [token] = Claper.Office.list_tokens(user)
    assert token.name == "Laptop"
    assert "office:interactions:write" in token.scopes
    assert has_element?(live, "#office-token-#{token.id}", "Laptop")

    live
    |> element("#office-token-#{token.id} button[phx-click='revoke-office-token']")
    |> render_click()

    assert Claper.Office.list_tokens(user) == []
    refute has_element?(live, "#office-token-#{token.id}")
  end
end
