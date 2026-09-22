defmodule Claper.OpenEndedTest do
  use Claper.DataCase

  alias Claper.OpenEnded
  alias Claper.OpenEnded.OpenEnded, as: Question
  alias Claper.OpenEnded.Response

  import Claper.{EventsFixtures, PresentationsFixtures, OpenEndedFixtures, AccountsFixtures}

  setup do
    event = event_fixture()
    presentation_file = presentation_file_fixture(%{event: event, length: 5})
    %{event: event, presentation_file: presentation_file}
  end

  describe "open ended questions" do
    test "list and fetch", %{event: event, presentation_file: pf} do
      item = open_ended_fixture(%{presentation_file_id: pf.id, position: 2})
      assert [%Question{}] = OpenEnded.list_open_ended(pf.id)
      assert [%Question{responses: []}] = OpenEnded.list_open_ended_at_position(pf.id, 2)
      assert %Question{total: 0} = OpenEnded.get_open_ended_for_event(item.id, event.id)
      assert is_nil(OpenEnded.get_open_ended_for_event(item.id, event_fixture().id))
      assert %Question{} = OpenEnded.get_open_ended_current_position(pf.id, 2)
      assert is_nil(OpenEnded.get_open_ended_current_position(pf.id, 3))
    end

    test "validates", %{presentation_file: pf} do
      assert {:error, changeset} =
               OpenEnded.create_open_ended(%{
                 title: "",
                 presentation_file_id: pf.id,
                 max_characters: 5000
               })

      assert %{title: _, max_characters: _} = errors_on(changeset)
    end

    test "create, update, delete broadcast", %{event: event, presentation_file: pf} do
      Phoenix.PubSub.subscribe(Claper.PubSub, "event:#{event.uuid}")
      item = open_ended_fixture(%{presentation_file_id: pf.id})
      assert_receive {:open_ended_created, %Question{}}

      {:ok, _} = OpenEnded.update_open_ended(event.uuid, item, %{title: "New"})
      assert_receive {:open_ended_updated, %Question{title: "New"}}

      {:ok, _} = OpenEnded.delete_open_ended(event.uuid, item)
      assert_receive {:open_ended_deleted, %Question{}}
    end
  end

  describe "submit_response/4" do
    setup %{presentation_file: pf} do
      %{item: open_ended_fixture(%{presentation_file_id: pf.id})}
    end

    test "stores cleaned text and keeps case", %{event: event, item: item} do
      assert {:ok, %Response{text: "Be Kind", status: "approved"},
              %Question{responses: [%Response{text: "Be Kind"}], total: 1}} =
               OpenEnded.submit_response("a", event.uuid, item, "  Be   Kind ")
    end

    test "multiple responses per person can be disabled", %{event: event, presentation_file: pf} do
      item = open_ended_fixture(%{presentation_file_id: pf.id, multiple_responses: false})
      assert {:ok, _, _} = OpenEnded.submit_response("a", event.uuid, item, "one")
      assert {:error, :limit_reached} = OpenEnded.submit_response("a", event.uuid, item, "two")
      assert {:ok, _, _} = OpenEnded.submit_response("b", event.uuid, item, "two")
    end

    test "allows several answers by default", %{event: event, item: item} do
      assert {:ok, _, _} = OpenEnded.submit_response("a", event.uuid, item, "one")

      assert {:ok, _, %Question{total: 2}} =
               OpenEnded.submit_response("a", event.uuid, item, "two")
    end

    test "rejects empty, too long, disabled, rate limited", %{
      event: event,
      item: item,
      presentation_file: pf
    } do
      assert {:error, :empty} = OpenEnded.submit_response("a", event.uuid, item, " ")

      assert {:error, :too_long} =
               OpenEnded.submit_response("a", event.uuid, item, String.duplicate("x", 201))

      disabled = open_ended_fixture(%{presentation_file_id: pf.id, enabled: false})
      assert {:error, :disabled} = OpenEnded.submit_response("a", event.uuid, disabled, "x")

      results = for i <- 1..12, do: OpenEnded.submit_response("burst", event.uuid, item, "r#{i}")
      assert Enum.count(results, &match?({:error, :rate_limited}, &1)) == 2
    end

    test "strips script tags", %{event: event, item: item} do
      assert {:ok, %Response{text: "alert(1)"}, _} =
               OpenEnded.submit_response("a", event.uuid, item, "<script>alert(1)</script>")
    end

    test "works for logged-in users", %{event: event, item: item} do
      user = user_fixture()

      assert {:ok, %Response{user_id: uid}, _} =
               OpenEnded.submit_response(user.id, event.uuid, item, "hi")

      assert uid == user.id
      assert [%Response{}] = OpenEnded.list_responses_for(user.id, item.id)
    end
  end

  describe "moderation" do
    test "pending answers are hidden until approved", %{event: event, presentation_file: pf} do
      item = open_ended_fixture(%{presentation_file_id: pf.id, moderation_enabled: true})

      {:ok, %Response{status: "pending"} = response, %Question{responses: [], pending_count: 1}} =
        OpenEnded.submit_response("a", event.uuid, item, "hidden")

      {:ok, _} = OpenEnded.moderate_response(event.uuid, response, "approved")

      assert %Question{responses: [%Response{text: "hidden"}], pending_count: 0} =
               OpenEnded.get_open_ended!(item.id)

      {:ok, _} = OpenEnded.delete_response(event.uuid, response)
      assert %Question{responses: []} = OpenEnded.get_open_ended!(item.id)
    end

    test "reset deletes all", %{event: event, presentation_file: pf} do
      item = open_ended_fixture(%{presentation_file_id: pf.id})
      {:ok, _, _} = OpenEnded.submit_response("a", event.uuid, item, "x")
      {:ok, _, _} = OpenEnded.submit_response("b", event.uuid, item, "y")
      assert {:ok, 2} = OpenEnded.delete_all_responses(event.uuid, item)
    end
  end

  describe "voting" do
    test "toggle_vote adds and removes one vote per attendee", %{
      event: event,
      presentation_file: pf
    } do
      item = open_ended_fixture(%{presentation_file_id: pf.id, voting_enabled: true})
      {:ok, response, _} = OpenEnded.submit_response("author", event.uuid, item, "x")

      assert {:ok, :voted, %Question{responses: [%Response{vote_count: 1}]}} =
               OpenEnded.toggle_vote("v1", event.uuid, item, response.id)

      assert {:ok, :voted, %Question{responses: [%Response{vote_count: 2}]}} =
               OpenEnded.toggle_vote("v2", event.uuid, item, response.id)

      assert OpenEnded.voted_response_ids("v1", item.id) == [response.id]

      assert {:ok, :unvoted, %Question{responses: [%Response{vote_count: 1}]}} =
               OpenEnded.toggle_vote("v1", event.uuid, item, response.id)

      assert OpenEnded.voted_response_ids("v1", item.id) == []
    end

    test "voting must be enabled and the response must exist", %{
      event: event,
      presentation_file: pf
    } do
      item = open_ended_fixture(%{presentation_file_id: pf.id, voting_enabled: false})
      {:ok, response, _} = OpenEnded.submit_response("a", event.uuid, item, "x")

      assert {:error, :voting_disabled} =
               OpenEnded.toggle_vote("v", event.uuid, item, response.id)

      {:ok, item} = OpenEnded.update_open_ended(event.uuid, item, %{voting_enabled: true})
      assert {:error, :not_found} = OpenEnded.toggle_vote("v", event.uuid, item, -1)
    end
  end

  test "export_rows/1", %{event: event, presentation_file: pf} do
    item = open_ended_fixture(%{presentation_file_id: pf.id})
    {:ok, _, _} = OpenEnded.submit_response("a", event.uuid, item, "Be kind")
    assert [["Be kind", 0, "approved", _]] = OpenEnded.export_rows(item.id)
  end
end
