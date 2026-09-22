defmodule Claper.Settings.GlobalConfig do
  use Ecto.Schema
  import Ecto.Changeset

  schema "global_configs" do
    field :key, :string
    field :value, :string
    field :encrypted_value, :binary

    timestamps()
  end

  @doc false
  def changeset(config, attrs) do
    config
    |> cast(attrs, [:key, :value, :encrypted_value])
    |> validate_required([:key])
    |> unique_constraint(:key)
  end
end
