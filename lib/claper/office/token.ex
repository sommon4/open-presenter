defmodule Claper.Office.Token do
  @moduledoc """
  A personal access token for the PowerPoint add-in (Office API).

  Only the SHA-256 hash of the token is stored. The plain token is shown to
  the user once, at creation.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @scopes ~w(office:events:read office:interactions:read office:presentation:read office:interactions:write)
  @default_scopes ~w(office:events:read office:interactions:read office:presentation:read)

  schema "office_tokens" do
    field :name, :string
    field :token_hash, :binary
    field :token_prefix, :string
    field :scopes, {:array, :string}, default: []
    field :last_used_at, :naive_datetime

    belongs_to :user, Claper.Accounts.User

    timestamps()
  end

  def scopes, do: @scopes
  def default_scopes, do: @default_scopes

  @doc false
  def changeset(token, attrs) do
    token
    |> cast(attrs, [:name, :token_hash, :token_prefix, :scopes, :user_id])
    |> validate_required([:name, :token_hash, :token_prefix, :user_id])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_subset(:scopes, @scopes)
    |> unique_constraint(:token_hash)
  end
end
