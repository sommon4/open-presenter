defmodule ClaperWeb.EventLive.OpenEndedLiveTest do
  use ClaperWeb.ConnCase

  import Phoenix.LiveViewTest
  import Claper.{PresentationsFixtures, OpenEndedFixtures}

  alias Claper.OpenEnded

  defp create_event(params) do
    presentation_file = presentation_file_fixture(%{user: params.user}, [:event])
    presentation_state_fixture(%{presentation_file: presentation_file, poll_visible: true})
    params |> Map.put(:presentation_file, presentation_file)
  end

  describe "Manage" do
    setup [:register_and_log_in_user, :create_event]

    test "creates an open ended question", %{conn: conn, presentation_file: pf} do
      {:ok, manage_live, _html} = live(conn, ~p"/e/#{pf.event.code}/manage/add/open_ended")

      manage_live
      |> form("#open-ended-form", %{
        "open_ended" => %{
          "title" => "What's the best advice you've ever been given?",
          "max_characters" => "200",
          "multiple_responses" => "true",
          "voting_enabled" => "true",
          "auto_scroll" => "true"
        }
      })
      |> render_submit()

      assert [item] = OpenEnded.list_open_ended(pf.id)
      assert item.voting_enabled and item.auto_scroll and item.multiple_responses
      refute item.enabled
    end

    test "activates, moderates, toggles voting and removes a response", %{
      conn: conn,
      presentation_file: pf
    } do
      item =
        open_ended_fixture(%{
          presentation_file_id: pf.id,
          position: 0,
          enabled: false,
          moderation_enabled: true
        })

      {:ok, manage_live, html} = live(conn, ~p"/e/#{pf.event.code}/manage")
      assert html =~ item.title

      manage_live |> element(~s(input[phx-click="open_ended-set-active"])) |> render_click()
      assert OpenEnded.get_open_ended!(item.id).enabled

      {:ok, response, _} =
        OpenEnded.submit_response("att", pf.event.uuid, %{item | enabled: true}, "Be kind")

      assert has_element?(manage_live, "[data-open-ended-pending='#{response.id}']")

      manage_live
      |> element(
        ~s(aside [data-open-ended-pending="#{response.id}"] button[phx-value-status="approved"])
      )
      |> render_click()

      assert %{responses: [%{text: "Be kind"}], pending_count: 0} =
               OpenEnded.get_open_ended!(item.id)

      # toggle voting from the options panel
      manage_live
      |> element(~s(aside button[phx-value-key="open_ended_voting"]))
      |> render_click()

      assert OpenEnded.get_open_ended!(item.id).voting_enabled

      manage_live
      |> element(
        ~s(aside [data-open-ended-response="#{response.id}"] button[phx-click="open-ended-delete-response"])
      )
      |> render_click()

      assert %{responses: []} = OpenEnded.get_open_ended!(item.id)

      # let the LiveView process pending broadcasts before the test exits
      _ = render(manage_live)
    end

    test "refuses another user's question", %{conn: conn, presentation_file: pf} do
      other = open_ended_fixture()

      {:ok, _live, html} =
        live(conn, ~p"/e/#{pf.event.code}/manage/edit/open_ended/#{other.id}")
        |> follow_redirect(conn)

      assert html =~ "Resource not found"
    end
  end

  describe "Show (attendee)" do
    setup [:register_and_log_in_user, :create_event]

    test "an attendee responds, sees all responses and votes", %{
      conn: conn,
      presentation_file: pf
    } do
      item = open_ended_fixture(%{presentation_file_id: pf.id, position: 0, voting_enabled: true})
      {:ok, other, _} = OpenEnded.submit_response("other", pf.event.uuid, item, "Sleep more")

      {:ok, show_live, html} = live(conn, ~p"/e/#{pf.event.code}")
      assert html =~ item.title
      assert has_element?(show_live, "#attendee-response-#{other.id}", "Sleep more")

      show_live
      |> form("#open-ended-form-#{item.id}-0", %{"text" => " Be kind "})
      |> render_submit()

      assert has_element?(show_live, "#open-ended-my-responses", "Be kind")
      # multiple responses on: the form is still there
      assert has_element?(show_live, "textarea[name=text]")

      show_live
      |> element(~s(#attendee-response-#{other.id} button[phx-click="vote-open-ended"]))
      |> render_click()

      assert has_element?(
               show_live,
               ~s(#attendee-response-#{other.id} button[aria-pressed="true"])
             )

      assert %{responses: [%{vote_count: 1}, _]} = OpenEnded.get_open_ended!(item.id)

      show_live
      |> element(~s(#attendee-response-#{other.id} button[phx-click="vote-open-ended"]))
      |> render_click()

      assert %{responses: [%{vote_count: 0}, _]} = OpenEnded.get_open_ended!(item.id)

      # let the LiveView process pending broadcasts before the test exits
      _ = render(show_live)
    end

    test "single response mode hides the form after one response", %{
      conn: conn,
      presentation_file: pf
    } do
      item =
        open_ended_fixture(%{presentation_file_id: pf.id, position: 0, multiple_responses: false})

      {:ok, show_live, _html} = live(conn, ~p"/e/#{pf.event.code}")

      show_live
      |> form("#open-ended-form-#{item.id}-0", %{"text" => "once"})
      |> render_submit()

      refute has_element?(show_live, "textarea[name=text]")
      assert render(show_live) =~ "Thank you!"

      # let the LiveView process pending broadcasts before the test exits
      _ = render(show_live)
    end

    test "responses are hidden when show_results is off", %{conn: conn, presentation_file: pf} do
      item = open_ended_fixture(%{presentation_file_id: pf.id, position: 0, show_results: false})
      {:ok, other, _} = OpenEnded.submit_response("other", pf.event.uuid, item, "hidden one")
      {:ok, show_live, _html} = live(conn, ~p"/e/#{pf.event.code}")
      refute has_element?(show_live, "#attendee-response-#{other.id}")

      # let the LiveView process pending broadcasts before the test exits
      _ = render(show_live)
    end
  end

  describe "Presenter" do
    setup [:register_and_log_in_user, :create_event]

    test "shows response cards live and escapes HTML", %{conn: conn, presentation_file: pf} do
      item = open_ended_fixture(%{presentation_file_id: pf.id, position: 0, auto_scroll: true})
      {:ok, presenter_live, html} = live(conn, ~p"/e/#{pf.event.code}/presenter")
      assert html =~ item.title
      assert html =~ "Waiting for responses"

      {:ok, r, _} = OpenEnded.submit_response("a", pf.event.uuid, item, "a&b <b>x</b>")

      html = render(presenter_live)
      assert has_element?(presenter_live, "#presenter-open-ended-#{item.id}-response-#{r.id}")
      assert html =~ "a&amp;b x"
      refute html =~ "<b>x</b>"
      assert html =~ ~s(data-auto-scroll="true")
      assert html =~ "1 response"

      # let the LiveView process pending broadcasts before the test exits
      _ = render(presenter_live)
    end
  end

  describe "Export" do
    setup [:register_and_log_in_user, :create_event]

    test "exports responses as CSV", %{conn: conn, presentation_file: pf} do
      item = open_ended_fixture(%{presentation_file_id: pf.id})
      {:ok, _, _} = OpenEnded.submit_response("a", pf.event.uuid, item, "Be kind")

      conn = post(conn, ~p"/export/open_ended/#{item.id}")
      assert response(conn, 200) =~ "Be kind"
    end

    test "forbids another user's export", %{conn: conn} do
      other = open_ended_fixture()
      assert response(post(conn, ~p"/export/open_ended/#{other.id}"), 403)
    end
  end
end
