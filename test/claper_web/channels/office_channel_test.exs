defmodule ClaperWeb.OfficeChannelTest do
  use ClaperWeb.ChannelCase

  import Claper.{AccountsFixtures, EventsFixtures, PresentationsFixtures, PollsFixtures}
  import Claper.WordCloudsFixtures

  alias Claper.Office

  setup do
    user = user_fixture()
    event = event_fixture(%{user: user})
    pf = presentation_file_fixture(%{event: event, length: 5})
    presentation_state_fixture(%{presentation_file: pf})
    {:ok, _plain, token} = Office.create_token(user, "test")

    socket_token =
      Phoenix.Token.sign(ClaperWeb.Endpoint, "office_socket", %{
        user_id: user.id,
        token_id: token.id
      })

    {:ok, socket} = connect(ClaperWeb.OfficeSocket, %{"token" => socket_token})
    %{user: user, event: event, pf: pf, socket: socket, token: token}
  end

  test "rejects a bad socket token" do
    assert :error = connect(ClaperWeb.OfficeSocket, %{"token" => "nope"})
    assert :error = connect(ClaperWeb.OfficeSocket, %{})
  end

  test "interaction topic pushes live results, start and stop", %{
    socket: socket,
    event: event,
    pf: pf
  } do
    wc = word_cloud_fixture(%{presentation_file_id: pf.id, position: 0, enabled: false})

    {:ok, %{interaction: %{id: id, type: "word_cloud"}}, _socket} =
      subscribe_and_join(socket, ClaperWeb.OfficeChannel, "interaction:word_cloud_#{wc.id}")

    assert id == "word_cloud_#{wc.id}"

    {:ok, _} = Claper.WordClouds.update_word_cloud(event.uuid, wc, %{enabled: true})
    wc = Claper.WordClouds.get_word_cloud!(wc.id)
    assert_push "interaction_updated", %{interaction: %{enabled: true}}

    {:ok, _, _} = Claper.WordClouds.submit_response("a", event.uuid, wc, "Genetics")

    assert_push "interaction_updated", %{
      interaction: %{results: %{words: [%{text: "Genetics", count: 1}]}}
    }

    Phoenix.PubSub.broadcast(Claper.PubSub, "event:#{event.uuid}", {:current_interaction, nil})
    assert_push "interaction_stopped", %{id: ^id}

    Phoenix.PubSub.broadcast(Claper.PubSub, "event:#{event.uuid}", {:current_interaction, wc})
    assert_push "interaction_started", %{interaction: %{id: ^id}}

    # an update of another interaction is not pushed on this topic
    poll = poll_fixture(%{presentation_file_id: pf.id, position: 1})
    {:ok, _} = Claper.Polls.update_poll(event.uuid, poll, %{title: "x"})
    refute_push "interaction_updated", %{interaction: %{type: "poll"}}

    {:ok, _} = Claper.WordClouds.delete_word_cloud(event.uuid, wc)
    assert_push "interaction_deleted", %{id: ^id}
  end

  test "event topic pushes state, current interaction and posts", %{
    socket: socket,
    event: event,
    pf: pf
  } do
    {:ok, %{event: %{id: uuid}}, _socket} =
      subscribe_and_join(socket, ClaperWeb.OfficeChannel, "event:#{event.uuid}")

    assert uuid == event.uuid

    state =
      Claper.Repo.get_by!(Claper.Presentations.PresentationState, presentation_file_id: pf.id)

    {:ok, _} = Claper.Presentations.update_presentation_state(state, %{position: 2})
    assert_push "state_updated", %{position: 2}

    poll = poll_fixture(%{presentation_file_id: pf.id, position: 2, enabled: true})
    Phoenix.PubSub.broadcast(Claper.PubSub, "event:#{event.uuid}", {:current_interaction, poll})
    assert_push "current_interaction", %{interaction: %{type: "poll"}}

    Claper.PostsFixtures.post_fixture(%{event: event, body: "Hello?"})
    assert_push "post_created", %{post: %{body: "Hello?"}}
  end

  test "refuses topics the user cannot access", %{socket: socket} do
    other = event_fixture()
    presentation_file_fixture(%{event: other})

    assert {:error, %{reason: "unauthorized"}} =
             subscribe_and_join(socket, ClaperWeb.OfficeChannel, "event:#{other.uuid}")

    assert {:error, %{reason: "unauthorized"}} =
             subscribe_and_join(socket, ClaperWeb.OfficeChannel, "interaction:poll_1")
  end
end
