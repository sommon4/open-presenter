defmodule ClaperWeb.UserSettingsLive.ShowTest do
  use ClaperWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Claper.Accounts

  setup :register_and_log_in_user

  test "shows the user's names", %{conn: conn, user: user} do
    {:ok, view, _html} = live(conn, ~p"/users/settings")

    assert has_element?(view, "p", user.first_name)
    assert has_element?(view, "p", user.last_name)
    assert has_element?(view, "a[href='/users/settings/edit/profile']", "Change")
  end

  test "updates the user's profile", %{conn: conn, user: user} do
    {:ok, view, _html} = live(conn, ~p"/users/settings/edit/profile")

    view
    |> form("#update_profile", %{
      "user" => %{"first_name" => "Jane", "last_name" => "Smith"}
    })
    |> render_submit()

    assert_redirect(view, ~p"/users/settings")

    updated_user = Accounts.get_user!(user.id)
    assert updated_user.first_name == "Jane"
    assert updated_user.last_name == "Smith"
  end

  test "requires both names", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/users/settings/edit/profile")

    html =
      view
      |> form("#update_profile", %{
        "user" => %{"first_name" => "", "last_name" => "Smith"}
      })
      |> render_submit()

    assert html =~ "can&#39;t be blank"
    assert has_element?(view, "#update_profile")
  end
end
