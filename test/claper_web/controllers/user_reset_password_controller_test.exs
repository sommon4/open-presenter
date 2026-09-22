defmodule ClaperWeb.UserResetPasswordControllerTest do
  use ClaperWeb.ConnCase, async: false

  import Claper.AccountsFixtures

  alias Claper.Accounts.UserToken
  alias Claper.Repo

  describe "GET /users/reset_password" do
    test "renders the reset password request page", %{conn: conn} do
      conn = get(conn, ~p"/users/reset_password")
      response = html_response(conn, 200)

      assert response =~ "action=\"/users/reset_password\""
      assert response =~ "name=\"user[email]\""
      assert response =~ "/users/log_in"
    end
  end

  describe "POST /users/reset_password" do
    test "redirects with a neutral message for existing users", %{conn: conn} do
      user = user_fixture()

      conn =
        post(conn, ~p"/users/reset_password", %{
          "user" => %{"email" => user.email}
        })

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"
    end

    test "redirects with the same neutral message for unknown users", %{conn: conn} do
      conn =
        post(conn, ~p"/users/reset_password", %{
          "user" => %{"email" => "unknown@example.com"}
        })

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"
    end
  end

  describe "GET /users/reset_password/:token" do
    test "renders the password update page for a valid token", %{conn: conn} do
      user = user_fixture()

      {token, user_token} = UserToken.build_email_token(user, "reset_password")
      Repo.insert!(user_token)

      conn = get(conn, ~p"/users/reset_password/#{token}")
      response = html_response(conn, 200)

      assert response =~ "action=\"/users/reset_password/#{token}\""
      assert response =~ "name=\"user[password]\""
      assert response =~ "name=\"user[password_confirmation]\""
    end
  end
end
