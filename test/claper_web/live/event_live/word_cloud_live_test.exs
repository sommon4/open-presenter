defmodule ClaperWeb.EventLive.WordCloudLiveTest do
  use ClaperWeb.ConnCase

  import Phoenix.LiveViewTest
  import Claper.{PresentationsFixtures, WordCloudsFixtures}

  alias Claper.WordClouds

  defp create_event(params) do
    presentation_file = presentation_file_fixture(%{user: params.user}, [:event])
    presentation_state_fixture(%{presentation_file: presentation_file, poll_visible: true})
    params |> Map.put(:presentation_file, presentation_file)
  end

  describe "Manage" do
    setup [:register_and_log_in_user, :create_event]

    test "creates a word cloud from the manager", %{conn: conn, presentation_file: pf} do
      {:ok, manage_live, _html} =
        live(conn, ~p"/e/#{pf.event.code}/manage/add/word_cloud")

      assert has_element?(manage_live, "#word-cloud-form")

      manage_live
      |> form("#word-cloud-form", %{
        "word_cloud" => %{
          "title" => "What causes diagnostic delay?",
          "max_answers" => "2",
          "max_characters" => "30",
          "moderation_enabled" => "true"
        }
      })
      |> render_submit()

      assert [word_cloud] = WordClouds.list_word_clouds(pf.id)
      assert word_cloud.title == "What causes diagnostic delay?"
      assert word_cloud.max_answers == 2
      assert word_cloud.max_characters == 30
      assert word_cloud.moderation_enabled
      refute word_cloud.enabled
    end

    test "shows validation errors", %{conn: conn, presentation_file: pf} do
      {:ok, manage_live, _html} =
        live(conn, ~p"/e/#{pf.event.code}/manage/add/word_cloud")

      html =
        manage_live
        |> form("#word-cloud-form", %{
          "word_cloud" => %{"title" => "Q", "max_answers" => "50"}
        })
        |> render_submit()

      assert html =~ "must be less than or equal to 10"
      assert WordClouds.list_word_clouds(pf.id) == []

      # let the LiveView process pending broadcasts before the test exits
      _ = render(manage_live)
    end

    test "activates a word cloud and shows the answers with moderation", %{
      conn: conn,
      presentation_file: pf
    } do
      word_cloud =
        word_cloud_fixture(%{
          presentation_file_id: pf.id,
          position: 0,
          enabled: false,
          moderation_enabled: true
        })

      {:ok, manage_live, html} = live(conn, ~p"/e/#{pf.event.code}/manage")
      assert html =~ word_cloud.title

      manage_live
      |> element(~s(input[phx-click="word_cloud-set-active"]))
      |> render_click()

      assert WordClouds.get_word_cloud!(word_cloud.id).enabled

      assert render(manage_live) =~ "Show word cloud on presentation" or
               render(manage_live) =~ "Hide word cloud on presentation"

      {:ok, response, _} =
        WordClouds.submit_response("att", pf.event.uuid, %{word_cloud | enabled: true}, "cost")

      html = render(manage_live)
      assert html =~ "cost"
      assert has_element?(manage_live, "[data-pending-response='#{response.id}']")

      manage_live
      |> element(
        ~s(aside [data-pending-response="#{response.id}"] button[phx-value-status="approved"])
      )
      |> render_click()

      assert %{words: [%{text: "cost", count: 1}], pending_count: 0} =
               WordClouds.get_word_cloud!(word_cloud.id)

      # the approved word is listed and can be removed
      manage_live
      |> element(~s(aside [data-word-cloud-words] button[phx-value-text="cost"]))
      |> render_click()

      assert %{words: []} = WordClouds.get_word_cloud!(word_cloud.id)

      # let the LiveView process pending broadcasts before the test exits
      _ = render(manage_live)
    end

    test "edits and deletes a word cloud", %{conn: conn, presentation_file: pf} do
      word_cloud = word_cloud_fixture(%{presentation_file_id: pf.id})

      {:ok, manage_live, _html} =
        live(conn, ~p"/e/#{pf.event.code}/manage/edit/word_cloud/#{word_cloud.id}")

      manage_live
      |> form("#word-cloud-form", %{"word_cloud" => %{"title" => "Renamed"}})
      |> render_submit()

      assert WordClouds.get_word_cloud!(word_cloud.id).title == "Renamed"

      {:ok, manage_live, _html} =
        live(conn, ~p"/e/#{pf.event.code}/manage/edit/word_cloud/#{word_cloud.id}")

      manage_live
      |> element(~s(a[phx-click="delete"]))
      |> render_click()

      assert WordClouds.list_word_clouds(pf.id) == []
    end

    test "refuses to edit another user's word cloud", %{conn: conn, presentation_file: pf} do
      other = word_cloud_fixture()

      {:ok, _live, html} =
        live(conn, ~p"/e/#{pf.event.code}/manage/edit/word_cloud/#{other.id}")
        |> follow_redirect(conn)

      assert html =~ "Resource not found"
    end
  end

  describe "Show (attendee)" do
    setup [:register_and_log_in_user, :create_event]

    test "an attendee submits answers and sees the live cloud", %{
      conn: conn,
      presentation_file: pf
    } do
      word_cloud =
        word_cloud_fixture(%{presentation_file_id: pf.id, position: 0, max_answers: 2})

      {:ok, show_live, html} = live(conn, ~p"/e/#{pf.event.code}")
      assert html =~ word_cloud.title
      assert has_element?(show_live, "input[name=word]")

      show_live
      |> form("#word-cloud-form-#{word_cloud.id}-0", %{"word" => " Genetics "})
      |> render_submit()

      assert has_element?(show_live, "#word-cloud-my-answers", "Genetics")
      assert render(show_live) =~ "1 answer left"

      # duplicate is rejected with a message
      html =
        show_live
        |> form("#word-cloud-form-#{word_cloud.id}-1", %{"word" => "genetics"})
        |> render_submit()

      assert html =~ "You already sent this answer"

      show_live
      |> form("#word-cloud-form-#{word_cloud.id}-1", %{"word" => "Family"})
      |> render_submit()

      assert render(show_live) =~ "Thank you!"
      refute has_element?(show_live, "input[name=word]")

      # the live cloud carries both words for the JS hook
      [words_json] =
        show_live
        |> render()
        |> Floki.parse_document!()
        |> Floki.attribute("#attendee-word-cloud-#{word_cloud.id}", "data-words")

      assert words_json =~ "Genetics"
      assert words_json =~ "Family"

      # let the LiveView process pending broadcasts before the test exits
      _ = render(show_live)
    end

    test "the live cloud is hidden when show_results is off", %{
      conn: conn,
      presentation_file: pf
    } do
      word_cloud =
        word_cloud_fixture(%{presentation_file_id: pf.id, position: 0, show_results: false})

      {:ok, show_live, _html} = live(conn, ~p"/e/#{pf.event.code}")
      refute has_element?(show_live, "#attendee-word-cloud-#{word_cloud.id}")

      # let the LiveView process pending broadcasts before the test exits
      _ = render(show_live)
    end

    test "another attendee's answer updates the cloud without refresh", %{
      conn: conn,
      presentation_file: pf
    } do
      word_cloud = word_cloud_fixture(%{presentation_file_id: pf.id, position: 0})
      {:ok, show_live, _html} = live(conn, ~p"/e/#{pf.event.code}")

      {:ok, _, _} = WordClouds.submit_response("other", pf.event.uuid, word_cloud, "access")

      assert render(show_live) =~ "access"

      # let the LiveView process pending broadcasts before the test exits
      _ = render(show_live)
    end

    test "the input disappears when the word cloud is disabled", %{
      conn: conn,
      presentation_file: pf
    } do
      word_cloud = word_cloud_fixture(%{presentation_file_id: pf.id, position: 0})
      {:ok, show_live, _html} = live(conn, ~p"/e/#{pf.event.code}")
      assert has_element?(show_live, "input[name=word]")

      {:ok, _} = WordClouds.update_word_cloud(pf.event.uuid, word_cloud, %{enabled: false})
      refute has_element?(show_live, "input[name=word]")

      # let the LiveView process pending broadcasts before the test exits
      _ = render(show_live)
    end
  end

  describe "Presenter" do
    setup [:register_and_log_in_user, :create_event]

    test "renders the cloud and receives live updates", %{conn: conn, presentation_file: pf} do
      word_cloud = word_cloud_fixture(%{presentation_file_id: pf.id, position: 0})

      {:ok, presenter_live, html} = live(conn, ~p"/e/#{pf.event.code}/presenter")
      assert html =~ word_cloud.title
      assert has_element?(presenter_live, "#presenter-word-cloud-#{word_cloud.id}")

      {:ok, _, _} = WordClouds.submit_response("a", pf.event.uuid, word_cloud, "Genetics")
      {:ok, _, _} = WordClouds.submit_response("b", pf.event.uuid, word_cloud, " genetics ")

      [words_json] =
        presenter_live
        |> render()
        |> Floki.parse_document!()
        |> Floki.attribute("#presenter-word-cloud-#{word_cloud.id}", "data-words")

      assert Jason.decode!(words_json) == [%{"text" => "Genetics", "count" => 2}]
      assert render(presenter_live) =~ "2 answers"

      # let the LiveView process pending broadcasts before the test exits
      _ = render(presenter_live)
    end

    test "escapes HTML in answers", %{conn: conn, presentation_file: pf} do
      word_cloud = word_cloud_fixture(%{presentation_file_id: pf.id, position: 0})
      {:ok, presenter_live, _html} = live(conn, ~p"/e/#{pf.event.code}/presenter")

      {:ok, _, _} =
        WordClouds.submit_response("a", pf.event.uuid, word_cloud, "a&b <script>x</script>")

      html = render(presenter_live)
      refute html =~ "<script>x</script>"
      assert html =~ "a&amp;b"

      # let the LiveView process pending broadcasts before the test exits
      _ = render(presenter_live)
    end
  end

  describe "Export" do
    setup [:register_and_log_in_user, :create_event]

    test "exports the aggregated answers as CSV", %{conn: conn, presentation_file: pf} do
      word_cloud = word_cloud_fixture(%{presentation_file_id: pf.id})
      {:ok, _, _} = WordClouds.submit_response("a", pf.event.uuid, word_cloud, "Genetics")
      {:ok, _, _} = WordClouds.submit_response("b", pf.event.uuid, word_cloud, "genetics")

      conn = post(conn, ~p"/export/word_clouds/#{word_cloud.id}")
      assert response_content_type(conn, :csv) =~ "text/csv"
      body = response(conn, 200)
      assert body =~ "Answer"
      assert body =~ "Genetics"
      assert body =~ "2"
    end

    test "forbids export for another user's word cloud", %{conn: conn} do
      other = word_cloud_fixture()
      conn = post(conn, ~p"/export/word_clouds/#{other.id}")
      assert response(conn, 403)
    end
  end
end
