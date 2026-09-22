defmodule Claper.Presentations.PresentationState do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer(),
          position: integer() | nil,
          chat_visible: boolean() | nil,
          poll_visible: boolean() | nil,
          join_screen_visible: boolean() | nil,
          chat_enabled: boolean() | nil,
          anonymous_chat_enabled: boolean() | nil,
          message_reaction_enabled: boolean() | nil,
          banned: [String.t()] | nil,
          show_only_pinned: boolean() | nil,
          show_attendee_count: boolean() | nil,
          poll_layout: String.t() | nil,
          poll_size: integer() | nil,
          poll_corner: String.t() | nil,
          presentation_file_id: integer() | nil,
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  @layouts ["overlay", "side", "corner", "bottom"]
  @corners ["top-left", "top-right", "bottom-left", "bottom-right"]
  @min_size 15
  @max_size 75

  def layouts, do: @layouts
  def corners, do: @corners
  def min_size, do: @min_size
  def max_size, do: @max_size

  schema "presentation_states" do
    field :position, :integer
    field :chat_visible, :boolean
    field :poll_visible, :boolean
    field :join_screen_visible, :boolean
    field :chat_enabled, :boolean
    field :anonymous_chat_enabled, :boolean
    field :message_reaction_enabled, :boolean, default: true
    field :banned, {:array, :string}, default: []
    field :show_only_pinned, :boolean, default: false
    field :show_attendee_count, :boolean, default: true
    field :poll_layout, :string, default: "overlay"
    field :poll_size, :integer, default: 40
    field :poll_corner, :string, default: "bottom-right"

    belongs_to :presentation_file, Claper.Presentations.PresentationFile

    timestamps()
  end

  @doc false
  def changeset(presentation_state, attrs) do
    presentation_state
    |> cast(attrs, [
      :position,
      :chat_visible,
      :poll_visible,
      :join_screen_visible,
      :banned,
      :presentation_file_id,
      :chat_enabled,
      :anonymous_chat_enabled,
      :show_only_pinned,
      :show_attendee_count,
      :message_reaction_enabled,
      :poll_layout,
      :poll_size,
      :poll_corner
    ])
    |> validate_required([])
    |> validate_inclusion(:poll_layout, @layouts)
    |> validate_inclusion(:poll_corner, @corners)
    |> validate_number(:poll_size,
      greater_than_or_equal_to: @min_size,
      less_than_or_equal_to: @max_size
    )
  end
end
