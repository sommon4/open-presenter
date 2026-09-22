defmodule Claper.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Claper.Accounts` context.
  """

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: "hello world!"

  def valid_user_attributes(attrs \\ %{}) do
    attrs = Enum.into(attrs, %{})
    password = Map.get(attrs, :password, valid_user_password())

    attrs
    |> Enum.into(%{
      email: unique_user_email(),
      first_name: "John",
      last_name: "Doe",
      password: password,
      confirmed_at: NaiveDateTime.utc_now()
    })
    |> Map.put_new(:password_confirmation, password)
  end

  def no_valid_user_attributes(attrs \\ %{}) do
    attrs = Enum.into(attrs, %{})
    password = Map.get(attrs, :password, valid_user_password())

    attrs
    |> Enum.into(%{
      email: unique_user_email(),
      first_name: "John",
      last_name: "Doe",
      password: password
    })
    |> Map.put_new(:password_confirmation, password)
  end

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> no_valid_user_attributes()
      |> Claper.Accounts.register_user()

    user
  end

  def confirmed_user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> Claper.Accounts.register_user()

    user
  end
end
