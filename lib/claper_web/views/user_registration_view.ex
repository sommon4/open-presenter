defmodule ClaperWeb.UserRegistrationView do
  import Phoenix.Component
  use ClaperWeb, :view

  alias Claper.Accounts.User

  def render("user.json", %{user_registration: user}) do
    %{
      email: user.email,
      name: User.display_name(user)
    }
  end
end
