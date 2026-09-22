defmodule ClaperWeb.PostLiveTest do
  use ClaperWeb.ConnCase

  import Phoenix.LiveViewTest
  import Claper.{PresentationsFixtures, PostsFixtures}

  alias Claper.Posts

  defp create_event(params) do
    presentation_file = presentation_file_fixture(%{user: params.user}, [:event])
    presentation_state_fixture(%{presentation_file: presentation_file})

    post =
      post_fixture(%{
        user: params.user,
        event: presentation_file.event,
        like_count: 1,
        love_count: 0,
        lol_count: 0
      })

    params |> Map.put(:presentation_file, presentation_file) |> Map.put(:post, post)
  end

  describe "Index" do
    setup [:register_and_log_in_user, :create_event]

    test "list posts", %{conn: conn, post: post, presentation_file: presentation_file} do
      {:ok, index_live, html} =
        live(conn, ~p"/e/#{presentation_file.event.code}")

      assert html =~ "some body"

      document = Floki.parse_document!(html)

      assert Floki.find(document, "[data-message-reaction-trigger]") == []
      assert Floki.find(document, "[data-message-reaction-menu]") == []
      assert [reaction_chip] = Floki.find(document, "[data-reaction-chip]")
      assert Floki.text(reaction_chip) =~ "1"
      assert Floki.attribute(reaction_chip, "disabled") != []
      assert reaction_chip |> Floki.attribute("class") |> List.first() =~ "text-gray-800"

      render_click(index_live, "react", %{"type" => "👍", "post-id" => post.uuid})
      assert Posts.get_post!(post.uuid).like_count == 1
    end

    test "allows reacting to another attendee's post", %{
      conn: conn,
      presentation_file: presentation_file
    } do
      post_fixture(%{event: presentation_file.event, like_count: 0})

      {:ok, _index_live, html} = live(conn, ~p"/e/#{presentation_file.event.code}")

      document = Floki.parse_document!(html)

      assert [_trigger] = Floki.find(document, "[data-message-reaction-trigger]")
      assert [_menu] = Floki.find(document, "[data-message-reaction-menu]")
    end
  end
end
