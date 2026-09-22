defmodule ClaperWeb.EventLive.PollLayoutLiveTest do
  use ClaperWeb.ConnCase

  import Phoenix.LiveViewTest
  import Claper.{PresentationsFixtures, PollsFixtures}

  alias Claper.{Polls, Presentations}

  defp get_state(id), do: Claper.Repo.get!(Claper.Presentations.PresentationState, id)

  defp create_event(params) do
    presentation_file = presentation_file_fixture(%{user: params.user}, [:event])

    state =
      presentation_state_fixture(%{presentation_file: presentation_file, poll_visible: true})

    params |> Map.put(:presentation_file, presentation_file) |> Map.put(:state, state)
  end

  describe "reset votes" do
    setup [:register_and_log_in_user, :create_event]

    test "reset_votes/2 deletes votes and zeroes counters", %{presentation_file: pf} do
      poll = poll_fixture(%{presentation_file_id: pf.id})
      [opt | _] = poll.poll_opts
      {:ok, voted} = Polls.vote("att-1", pf.event.uuid, [opt], poll.id)
      [opt | _] = voted.poll_opts
      {:ok, _} = Polls.vote("att-2", pf.event.uuid, [opt], poll.id)

      assert %{poll_opts: [%{vote_count: 2} | _]} = Polls.get_poll!(poll.id)
      assert length(Polls.get_poll_vote("att-1", poll.id)) == 1

      assert {:ok, %Polls.Poll{} = reset} = Polls.reset_votes(pf.event.uuid, poll)
      assert Enum.all?(reset.poll_opts, &(&1.vote_count == 0))
      assert Polls.get_poll_vote("att-1", poll.id) == []
      assert Polls.get_poll_vote("att-2", poll.id) == []
    end

    test "the manager resets a poll and the attendee can vote again", %{
      conn: conn,
      presentation_file: pf
    } do
      poll = poll_fixture(%{presentation_file_id: pf.id, position: 0})
      [opt | _] = poll.poll_opts
      {:ok, _} = Polls.vote("att-1", pf.event.uuid, [opt], poll.id)

      {:ok, manage_live, html} = live(conn, ~p"/e/#{pf.event.code}/manage")
      assert html =~ "1 vote"
      assert has_element?(manage_live, ~s(aside button[phx-click="poll-reset"]))

      manage_live
      |> element(~s(aside button[phx-click="poll-reset"]))
      |> render_click()

      assert Polls.get_poll_vote("att-1", poll.id) == []
      html = render(manage_live)
      assert html =~ "0 vote"
      refute has_element?(manage_live, ~s(aside button[phx-click="poll-reset"]))
    end

    test "refuses to reset another user's poll", %{conn: conn, presentation_file: pf} do
      other_pf = presentation_file_fixture(%{}, [:event])
      other = poll_fixture(%{presentation_file_id: other_pf.id})
      [opt | _] = other.poll_opts
      {:ok, _} = Polls.vote("att-1", other_pf.event.uuid, [opt], other.id)

      {:ok, manage_live, _html} = live(conn, ~p"/e/#{pf.event.code}/manage")
      render_click(manage_live, "poll-reset", %{"id" => other.id})

      assert length(Polls.get_poll_vote("att-1", other.id)) == 1
    end
  end

  describe "layout" do
    setup [:register_and_log_in_user, :create_event]

    test "the manager changes layout, size and corner", %{
      conn: conn,
      presentation_file: pf,
      state: state
    } do
      _poll = poll_fixture(%{presentation_file_id: pf.id, position: 0})
      {:ok, manage_live, _html} = live(conn, ~p"/e/#{pf.event.code}/manage")

      assert has_element?(manage_live, ~s(aside [data-poll-layout]))
      refute has_element?(manage_live, ~s(aside [data-poll-size]))

      manage_live
      |> element(~s(aside button[phx-click="poll-layout"][phx-value-layout="side"]))
      |> render_click()

      assert get_state(state.id).poll_layout == "side"
      assert has_element?(manage_live, ~s(aside [data-poll-size]))

      manage_live
      |> element(~s(aside form[data-poll-size]))
      |> render_change(%{"size" => "25"})

      assert get_state(state.id).poll_size == 25

      manage_live
      |> element(~s(aside button[phx-click="poll-layout"][phx-value-layout="corner"]))
      |> render_click()

      manage_live
      |> element(~s(aside button[phx-click="poll-corner"][phx-value-corner="top-left"]))
      |> render_click()

      updated = get_state(state.id)
      assert updated.poll_layout == "corner"
      assert updated.poll_corner == "top-left"

      # invalid values are ignored
      render_click(manage_live, "poll-layout", %{"layout" => "diagonal"})
      render_change(manage_live, "poll-size", %{"size" => "99"})
      updated = get_state(state.id)
      assert updated.poll_layout == "corner"
      assert updated.poll_size == 25

      # let the LiveView process pending broadcasts before the test exits
      _ = render(manage_live)
    end

    test "the presenter places the panel and makes room for the slide", %{
      conn: conn,
      presentation_file: pf,
      state: state
    } do
      poll = poll_fixture(%{presentation_file_id: pf.id, position: 0})
      {:ok, presenter_live, html} = live(conn, ~p"/e/#{pf.event.code}/presenter")
      assert html =~ poll.title
      assert has_element?(presenter_live, ~s(#poll[data-layout="overlay"]))
      assert has_element?(presenter_live, ~s(#presenter[data-poll-layout="overlay"]))

      {:ok, _} =
        Presentations.update_presentation_state(state, %{poll_layout: "side", poll_size: 30})

      assert has_element?(presenter_live, ~s(#poll[data-layout="side"]))
      assert has_element?(presenter_live, ~s(#presenter[data-poll-layout="side"]))
      assert render(presenter_live) =~ "--poll-size: 30%"
      assert render(presenter_live) =~ "width: 30%;"

      {:ok, _} =
        Presentations.update_presentation_state(
          get_state(state.id),
          %{poll_layout: "corner", poll_corner: "top-left"}
        )

      assert has_element?(presenter_live, ~s(#poll[data-layout="corner"].top-4.left-4))

      {:ok, _} =
        Presentations.update_presentation_state(
          get_state(state.id),
          %{poll_layout: "bottom"}
        )

      assert has_element?(presenter_live, ~s(#poll[data-layout="bottom"]))
      assert render(presenter_live) =~ "height: 30vh;"

      # hidden panel: the slide takes the whole screen again
      {:ok, _} =
        Presentations.update_presentation_state(
          get_state(state.id),
          %{poll_visible: false}
        )

      assert has_element?(presenter_live, ~s(#presenter[data-poll-layout="overlay"]))
      assert has_element?(presenter_live, ~s(#poll.pointer-events-none))

      # let the LiveView process pending broadcasts before the test exits
      _ = render(presenter_live)
    end
  end
end
