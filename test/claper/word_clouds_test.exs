defmodule Claper.WordCloudsTest do
  use Claper.DataCase

  alias Claper.WordClouds
  alias Claper.WordClouds.{WordCloud, WordCloudResponse}

  import Claper.{EventsFixtures, PresentationsFixtures, WordCloudsFixtures, AccountsFixtures}

  setup do
    event = event_fixture()
    presentation_file = presentation_file_fixture(%{event: event, length: 5})
    %{event: event, presentation_file: presentation_file}
  end

  describe "word clouds" do
    test "list_word_clouds/1 returns the word clouds of a presentation", %{
      presentation_file: pf
    } do
      word_cloud = word_cloud_fixture(%{presentation_file_id: pf.id})
      assert [%WordCloud{id: id}] = WordClouds.list_word_clouds(pf.id)
      assert id == word_cloud.id
    end

    test "list_word_clouds_at_position/2 filters by position", %{presentation_file: pf} do
      word_cloud_fixture(%{presentation_file_id: pf.id, position: 1})
      word_cloud = word_cloud_fixture(%{presentation_file_id: pf.id, position: 3})

      assert [%WordCloud{id: id}] = WordClouds.list_word_clouds_at_position(pf.id, 3)
      assert id == word_cloud.id
    end

    test "get_word_cloud_for_event/2 is scoped to the event", %{
      event: event,
      presentation_file: pf
    } do
      word_cloud = word_cloud_fixture(%{presentation_file_id: pf.id})
      other_event = event_fixture()

      assert %WordCloud{words: [], total: 0} =
               WordClouds.get_word_cloud_for_event(word_cloud.id, event.id)

      assert is_nil(WordClouds.get_word_cloud_for_event(word_cloud.id, other_event.id))
    end

    test "get_word_cloud_current_position/2 returns only the enabled word cloud", %{
      presentation_file: pf
    } do
      word_cloud_fixture(%{presentation_file_id: pf.id, position: 2, enabled: false})
      enabled = word_cloud_fixture(%{presentation_file_id: pf.id, position: 2, enabled: true})

      assert %WordCloud{id: id} = WordClouds.get_word_cloud_current_position(pf.id, 2)
      assert id == enabled.id
      assert is_nil(WordClouds.get_word_cloud_current_position(pf.id, 4))
    end

    test "create_word_cloud/1 validates limits", %{presentation_file: pf} do
      assert {:error, changeset} =
               WordClouds.create_word_cloud(%{
                 title: "",
                 presentation_file_id: pf.id,
                 max_answers: 0,
                 max_characters: 500
               })

      assert %{title: _, max_answers: _, max_characters: _} = errors_on(changeset)
    end

    test "create_word_cloud/1 broadcasts on the event topic", %{
      event: event,
      presentation_file: pf
    } do
      Phoenix.PubSub.subscribe(Claper.PubSub, "event:#{event.uuid}")

      {:ok, word_cloud} =
        WordClouds.create_word_cloud(%{title: "Q", presentation_file_id: pf.id, position: 0})

      assert_receive {:word_cloud_created, %WordCloud{id: id}}
      assert id == word_cloud.id
    end

    test "update_word_cloud/3 and delete_word_cloud/2 broadcast", %{
      event: event,
      presentation_file: pf
    } do
      word_cloud = word_cloud_fixture(%{presentation_file_id: pf.id})
      Phoenix.PubSub.subscribe(Claper.PubSub, "event:#{event.uuid}")

      assert {:ok, %WordCloud{title: "New"}} =
               WordClouds.update_word_cloud(event.uuid, word_cloud, %{title: "New"})

      assert_receive {:word_cloud_updated, %WordCloud{title: "New"}}

      assert {:ok, _} = WordClouds.delete_word_cloud(event.uuid, word_cloud)
      assert_receive {:word_cloud_deleted, %WordCloud{}}
      assert WordClouds.list_word_clouds(pf.id) == []
    end

    test "deleting a word cloud deletes its responses", %{event: event, presentation_file: pf} do
      word_cloud = word_cloud_fixture(%{presentation_file_id: pf.id})
      {:ok, _, _} = WordClouds.submit_response("att-1", event.uuid, word_cloud, "genetics")
      assert length(WordClouds.list_responses(word_cloud.id)) == 1

      {:ok, _} = WordClouds.delete_word_cloud(event.uuid, word_cloud)
      assert Repo.aggregate(WordCloudResponse, :count) == 0
    end
  end

  describe "submit_response/4" do
    setup %{presentation_file: pf} do
      %{word_cloud: word_cloud_fixture(%{presentation_file_id: pf.id})}
    end

    test "stores the display form and merges case and whitespace", %{
      event: event,
      word_cloud: word_cloud
    } do
      assert {:ok, %WordCloudResponse{original_text: "Genetics", normalized_text: "genetics"},
              %WordCloud{words: [%{text: "Genetics", count: 1}], total: 1}} =
               WordClouds.submit_response("att-1", event.uuid, word_cloud, " Genetics ")

      assert {:ok, _, %WordCloud{words: [%{text: "Genetics", count: 2}], total: 2}} =
               WordClouds.submit_response("att-2", event.uuid, word_cloud, "GENETICS")

      assert {:ok, _, %WordCloud{words: [%{text: "Genetics", count: 3}]}} =
               WordClouds.submit_response("att-3", event.uuid, word_cloud, "genetics")
    end

    test "aggregates by descending count then text", %{event: event, word_cloud: word_cloud} do
      for {att, text} <- [
            {"a", "AI"},
            {"b", "ai"},
            {"c", "counselling"},
            {"d", "genetics"},
            {"e", "genetics"},
            {"f", "genetics"}
          ] do
        {:ok, _, _} = WordClouds.submit_response(att, event.uuid, word_cloud, text)
      end

      assert %WordCloud{
               words: [
                 %{text: "genetics", count: 3},
                 %{text: "AI", count: 2},
                 %{text: "counselling", count: 1}
               ],
               total: 6
             } = WordClouds.get_word_cloud!(word_cloud.id)
    end

    test "works for logged-in users", %{event: event, word_cloud: word_cloud} do
      user = user_fixture()

      assert {:ok, %WordCloudResponse{user_id: user_id, attendee_identifier: nil}, _} =
               WordClouds.submit_response(user.id, event.uuid, word_cloud, "family")

      assert user_id == user.id
      assert [%WordCloudResponse{}] = WordClouds.list_responses_for(user.id, word_cloud.id)
    end

    test "rejects empty, too long, and duplicate answers", %{
      event: event,
      word_cloud: word_cloud
    } do
      assert {:error, :empty} = WordClouds.submit_response("a", event.uuid, word_cloud, "   ")

      assert {:error, :too_long} =
               WordClouds.submit_response("a", event.uuid, word_cloud, String.duplicate("x", 41))

      assert {:ok, _, _} = WordClouds.submit_response("a", event.uuid, word_cloud, "Future")

      assert {:error, :duplicate} =
               WordClouds.submit_response("a", event.uuid, word_cloud, "future")
    end

    test "enforces max_answers per attendee", %{event: event, presentation_file: pf} do
      word_cloud = word_cloud_fixture(%{presentation_file_id: pf.id, max_answers: 2})

      assert {:ok, _, _} = WordClouds.submit_response("a", event.uuid, word_cloud, "one")
      assert {:ok, _, _} = WordClouds.submit_response("a", event.uuid, word_cloud, "two")

      assert {:error, :limit_reached} =
               WordClouds.submit_response("a", event.uuid, word_cloud, "three")

      # another attendee is not affected
      assert {:ok, _, _} = WordClouds.submit_response("b", event.uuid, word_cloud, "three")
    end

    test "rejects when disabled", %{event: event, presentation_file: pf} do
      word_cloud = word_cloud_fixture(%{presentation_file_id: pf.id, enabled: false})
      assert {:error, :disabled} = WordClouds.submit_response("a", event.uuid, word_cloud, "x")
    end

    test "rate limits bursts from one attendee", %{event: event, presentation_file: pf} do
      word_cloud = word_cloud_fixture(%{presentation_file_id: pf.id, max_answers: 10})

      results =
        for i <- 1..12 do
          WordClouds.submit_response("burst", event.uuid, word_cloud, "w#{i}")
        end

      assert Enum.count(results, &match?({:ok, _, _}, &1)) == 10
      assert Enum.count(results, &match?({:error, :rate_limited}, &1)) == 2
    end

    test "strips HTML and script input", %{event: event, word_cloud: word_cloud} do
      assert {:ok, %WordCloudResponse{original_text: "alert(1)"}, _} =
               WordClouds.submit_response(
                 "a",
                 event.uuid,
                 word_cloud,
                 "<script>alert(1)</script>"
               )
    end

    test "keeps case when merge_case is off", %{event: event, presentation_file: pf} do
      word_cloud = word_cloud_fixture(%{presentation_file_id: pf.id, merge_case: false})
      {:ok, _, _} = WordClouds.submit_response("a", event.uuid, word_cloud, "AI")
      {:ok, _, wc} = WordClouds.submit_response("b", event.uuid, word_cloud, "ai")
      assert length(wc.words) == 2
    end

    test "filters profanity when enabled", %{event: event, presentation_file: pf} do
      word_cloud =
        word_cloud_fixture(%{presentation_file_id: pf.id, profanity_filter_enabled: true})

      assert {:error, :profanity} =
               WordClouds.submit_response("a", event.uuid, word_cloud, "$h1t")

      assert {:ok, _, _} = WordClouds.submit_response("a", event.uuid, word_cloud, "class")
    end

    test "broadcasts word_cloud_updated with the aggregation", %{
      event: event,
      word_cloud: word_cloud
    } do
      Phoenix.PubSub.subscribe(Claper.PubSub, "event:#{event.uuid}")
      {:ok, _, _} = WordClouds.submit_response("a", event.uuid, word_cloud, "Genetics")

      assert_receive {:word_cloud_updated, %WordCloud{words: [%{text: "Genetics", count: 1}]}}

      {:ok, _, _} = WordClouds.submit_response("b", event.uuid, word_cloud, " genetics ")
      assert_receive {:word_cloud_updated, %WordCloud{words: [%{text: "Genetics", count: 2}]}}
    end
  end

  describe "moderation" do
    setup %{presentation_file: pf} do
      %{
        word_cloud: word_cloud_fixture(%{presentation_file_id: pf.id, moderation_enabled: true})
      }
    end

    test "pending responses are not counted until approved", %{
      event: event,
      word_cloud: word_cloud
    } do
      assert {:ok, %WordCloudResponse{status: "pending"} = response,
              %WordCloud{words: [], pending_count: 1}} =
               WordClouds.submit_response("a", event.uuid, word_cloud, "access")

      assert {:ok, %WordCloudResponse{status: "approved"}} =
               WordClouds.moderate_response(event.uuid, response, "approved")

      assert %WordCloud{words: [%{text: "access", count: 1}], pending_count: 0} =
               WordClouds.get_word_cloud!(word_cloud.id)
    end

    test "rejected responses free the attendee's slot", %{
      event: event,
      presentation_file: pf
    } do
      word_cloud =
        word_cloud_fixture(%{
          presentation_file_id: pf.id,
          moderation_enabled: true,
          max_answers: 1
        })

      {:ok, response, _} = WordClouds.submit_response("a", event.uuid, word_cloud, "cost")

      assert {:error, :limit_reached} =
               WordClouds.submit_response("a", event.uuid, word_cloud, "x")

      {:ok, _} = WordClouds.moderate_response(event.uuid, response, "rejected")
      assert {:ok, _, _} = WordClouds.submit_response("a", event.uuid, word_cloud, "x")
      assert [] == WordClouds.aggregate(word_cloud.id) |> Enum.filter(&(&1.text == "cost"))
    end

    test "get_response_for_event/2 is scoped", %{event: event, word_cloud: word_cloud} do
      {:ok, response, _} = WordClouds.submit_response("a", event.uuid, word_cloud, "x")
      assert %WordCloudResponse{} = WordClouds.get_response_for_event(response.id, event.id)
      assert is_nil(WordClouds.get_response_for_event(response.id, event_fixture().id))
    end
  end

  describe "deletion" do
    test "delete_word/3 removes every response with that key", %{
      event: event,
      presentation_file: pf
    } do
      word_cloud = word_cloud_fixture(%{presentation_file_id: pf.id})
      {:ok, _, _} = WordClouds.submit_response("a", event.uuid, word_cloud, "Spam")
      {:ok, _, _} = WordClouds.submit_response("b", event.uuid, word_cloud, "spam")
      {:ok, _, _} = WordClouds.submit_response("c", event.uuid, word_cloud, "ok")

      assert {:ok, 2} = WordClouds.delete_word(event.uuid, word_cloud, "spam")
      assert [%{text: "ok", count: 1}] = WordClouds.aggregate(word_cloud.id)
    end

    test "delete_all_responses/2 resets the cloud", %{event: event, presentation_file: pf} do
      word_cloud = word_cloud_fixture(%{presentation_file_id: pf.id})
      {:ok, _, _} = WordClouds.submit_response("a", event.uuid, word_cloud, "one")
      {:ok, _, _} = WordClouds.submit_response("b", event.uuid, word_cloud, "two")

      assert {:ok, 2} = WordClouds.delete_all_responses(event.uuid, word_cloud)
      assert [] = WordClouds.aggregate(word_cloud.id)
    end
  end

  describe "with_sizes/3" do
    test "maps counts to font sizes between min and max" do
      words = [%{text: "a", count: 10}, %{text: "b", count: 5}, %{text: "c", count: 1}]
      [a, b, c] = WordClouds.with_sizes(words, 24, 96)
      assert a.size == 96
      assert c.size == 24
      assert b.size > 24 and b.size < 96
    end

    test "uses a mid size when all counts are equal" do
      assert [%{size: 60}, %{size: 60}] =
               WordClouds.with_sizes([%{text: "a", count: 2}, %{text: "b", count: 2}], 24, 96)
    end

    test "handles an empty list" do
      assert [] == WordClouds.with_sizes([])
    end
  end

  describe "export_rows/1" do
    test "returns display, key and count", %{event: event, presentation_file: pf} do
      word_cloud = word_cloud_fixture(%{presentation_file_id: pf.id})
      {:ok, _, _} = WordClouds.submit_response("a", event.uuid, word_cloud, "Genetics")
      {:ok, _, _} = WordClouds.submit_response("b", event.uuid, word_cloud, "genetics")

      assert [["Genetics", "genetics", 2]] = WordClouds.export_rows(word_cloud.id)
    end
  end
end
