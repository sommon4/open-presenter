defmodule Claper.OfficeTest do
  use Claper.DataCase

  alias Claper.Office
  alias Claper.Office.Token

  import Claper.{AccountsFixtures, EventsFixtures, PresentationsFixtures, PollsFixtures}
  import Claper.{WordCloudsFixtures, OpenEndedFixtures}

  describe "tokens" do
    test "create, verify, list and delete" do
      user = user_fixture()
      assert {:ok, plain, %Token{} = token} = Office.create_token(user, "Laptop")
      assert String.starts_with?(plain, "claper_office_")
      assert token.token_prefix == String.slice(plain, 0, 20)
      assert token.scopes == Token.default_scopes()
      refute Office.has_scope?(token, "office:interactions:write")

      assert {:ok, %Token{user: %{id: uid}, last_used_at: %NaiveDateTime{}}} =
               Office.verify_token(plain)

      assert uid == user.id
      assert {:error, :invalid_token} = Office.verify_token("claper_office_nope")
      assert {:error, :invalid_token} = Office.verify_token("something else")
      assert {:error, :invalid_token} = Office.verify_token(nil)

      assert [%Token{id: id}] = Office.list_tokens(user)
      assert id == token.id
      assert {:error, :not_found} = Office.delete_token(user_fixture(), token.id)
      assert {:ok, _} = Office.delete_token(user, token.id)
      assert Office.list_tokens(user) == []
      assert {:error, :invalid_token} = Office.verify_token(plain)
    end

    test "write scope can be granted" do
      user = user_fixture()
      {:ok, _, token} = Office.create_token(user, "Full", Token.scopes())
      assert Office.has_scope?(token, "office:interactions:write")
    end
  end

  describe "events and interactions" do
    setup do
      user = user_fixture()
      event = event_fixture(%{user: user})
      pf = presentation_file_fixture(%{event: event, length: 5})
      presentation_state_fixture(%{presentation_file: pf})
      %{user: user, event: event, pf: pf}
    end

    test "list_events includes owned and facilitated events", %{user: user, event: event} do
      other_owner = user_fixture()
      led = event_fixture(%{user: other_owner})
      presentation_file_fixture(%{event: led})
      {:ok, _} = Claper.Events.create_activity_leader(%{event_id: led.id, email: user.email})

      ids = Office.list_events(user) |> Enum.map(& &1.id)
      assert event.id in ids
      assert led.id in ids
      refute event_fixture().id in ids
    end

    test "get_event/2 is scoped", %{user: user, event: event} do
      assert {:ok, %{id: id}} = Office.get_event(user, event.uuid)
      assert id == event.id
      assert {:error, :not_found} = Office.get_event(user_fixture(), event.uuid)
      assert {:error, :not_found} = Office.get_event(user, "not-a-uuid")
    end

    test "list_interactions and get_interaction", %{user: user, event: event, pf: pf} do
      poll = poll_fixture(%{presentation_file_id: pf.id, position: 1})
      wc = word_cloud_fixture(%{presentation_file_id: pf.id, position: 0})
      oe = open_ended_fixture(%{presentation_file_id: pf.id, position: 2})

      {:ok, event} = Office.get_event(user, event.uuid)
      ids = Office.list_interactions(event) |> Enum.map(&Office.public_id/1)
      assert ids == ["word_cloud_#{wc.id}", "poll_#{poll.id}", "open_ended_#{oe.id}"]

      assert {:ok, %Claper.Polls.Poll{}, %Claper.Events.Event{}} =
               Office.get_interaction(user, "poll_#{poll.id}")

      assert {:ok, %Claper.WordClouds.WordCloud{words: []}, _} =
               Office.get_interaction(user, "word_cloud_#{wc.id}")

      assert {:error, :not_found} = Office.get_interaction(user_fixture(), "poll_#{poll.id}")
      assert {:error, :not_found} = Office.get_interaction(user, "poll_999999")
      assert {:error, :not_found} = Office.get_interaction(user, "banana_1")
      assert {:error, :not_found} = Office.get_interaction(user, "poll_x")
    end

    test "set_active/3 enables one interaction and disables the others", %{
      user: user,
      event: event,
      pf: pf
    } do
      poll = poll_fixture(%{presentation_file_id: pf.id, position: 0, enabled: true})
      wc = word_cloud_fixture(%{presentation_file_id: pf.id, position: 0, enabled: false})
      {:ok, event} = Office.get_event(user, event.uuid)
      Phoenix.PubSub.subscribe(Claper.PubSub, "event:#{event.uuid}")

      assert {:ok, %{enabled: true}} = Office.set_active(wc, event, true)
      assert_receive {:current_interaction, %Claper.WordClouds.WordCloud{}}
      refute Claper.Polls.get_poll!(poll.id).enabled

      assert {:ok, %{enabled: false}} = Office.set_active(wc, event, false)
      assert_receive {:current_interaction, nil}
    end
  end

  describe "serializer" do
    test "serializes every interaction type with results" do
      user = user_fixture()
      event = event_fixture(%{user: user})
      pf = presentation_file_fixture(%{event: event, length: 3})
      presentation_state_fixture(%{presentation_file: pf})
      {:ok, event} = Office.get_event(user, event.uuid)

      poll = poll_fixture(%{presentation_file_id: pf.id})
      wc = word_cloud_fixture(%{presentation_file_id: pf.id})
      {:ok, _, _} = Claper.WordClouds.submit_response("a", event.uuid, wc, "Genetics")
      oe = open_ended_fixture(%{presentation_file_id: pf.id})
      {:ok, _, _} = Claper.OpenEnded.submit_response("a", event.uuid, oe, "Be kind")

      {:ok, poll, _} = Office.get_interaction(user, "poll_#{poll.id}")
      {:ok, wc, _} = Office.get_interaction(user, "word_cloud_#{wc.id}")
      {:ok, oe, _} = Office.get_interaction(user, "open_ended_#{oe.id}")

      assert %{type: "poll", results: %{options: [_, _], total_votes: 0}, join_code: code} =
               Office.Serializer.interaction(poll, event)

      assert code == String.upcase(event.code)

      assert %{type: "word_cloud", results: %{words: [%{text: "Genetics", count: 1, size: _}]}} =
               Office.Serializer.interaction(wc, event)

      assert %{type: "open_ended", results: %{responses: [%{text: "Be kind"}]}} =
               Office.Serializer.interaction(oe, event)

      assert Jason.encode!(Office.Serializer.interaction(wc, event)) =~ "Genetics"
      assert %{join_url: url, slides: 3, position: 0} = Office.Serializer.event(event)
      assert url =~ "/e/#{event.code}"
    end
  end
end
