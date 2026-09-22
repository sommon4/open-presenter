defmodule Claper.AuditTest do
  use Claper.DataCase

  alias Claper.Audit

  describe "audit_logs" do
    alias Claper.Audit.Log

    import Claper.AuditFixtures
    import Claper.AccountsFixtures

    @invalid_attrs %{action: nil}

    test "list_logs/0 paginates all audit_logs" do
      log = log_fixture()
      {logs, _meta} = Audit.list_logs()
      assert Enum.any?(logs, fn l -> l.id == log.id end)
    end

    test "get_log!/1 returns the log with given id" do
      log = log_fixture()
      fetched_log = Audit.get_log!(log.id)
      assert fetched_log.id == log.id
      assert fetched_log.action == log.action
    end

    test "create_log/1 with valid data creates a log" do
      valid_attrs = %{
        metadata: %{},
        action: "some action",
        resource_type: "some resource_type",
        resource_id: 42
      }

      assert {:ok, %Log{} = log} = Audit.create_log(valid_attrs)
      assert log.metadata == %{}
      assert log.action == "some action"
      assert log.resource_type == "some resource_type"
      assert log.resource_id == 42
    end

    test "create_log/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Audit.create_log(@invalid_attrs)
    end

    test "log_action/3 creates a log for a user" do
      user = user_fixture()
      metadata = %{ip_address: "127.0.0.1"}

      assert {:ok, %Log{} = log} = Audit.log_action(user, "user.login", metadata)
      assert log.user_id == user.id
      assert log.action == "user.login"
      assert log.metadata == metadata
    end

    test "log_action/3 creates a log without a user" do
      metadata = %{reason: "system startup"}

      assert {:ok, %Log{} = log} = Audit.log_action(nil, "system.startup", metadata)
      assert log.user_id == nil
      assert log.action == "system.startup"
      assert log.metadata == metadata
    end

    test "log_resource_action/5 creates a log with resource info" do
      user = user_fixture()
      metadata = %{}

      assert {:ok, %Log{} = log} =
               Audit.log_resource_action(user, "event.create", "event", 123, metadata)

      assert log.user_id == user.id
      assert log.action == "event.create"
      assert log.resource_type == "event"
      assert log.resource_id == 123
    end

    test "list_logs_for_user/2 scopes to a single user, descending by timestamp" do
      user = user_fixture()
      other = user_fixture()

      _other_log = log_fixture(%{user_id: other.id, action: "other.action"})

      older =
        log_fixture(%{
          user_id: user.id,
          action: "user.first"
        })

      newer =
        log_fixture(%{
          user_id: user.id,
          action: "user.second"
        })

      # Force a deterministic order even when the inserts share a timestamp.
      {1, _} =
        Claper.Repo.update_all(
          Ecto.Query.from(l in Log, where: l.id == ^older.id),
          set: [inserted_at: ~N[2026-01-01 10:00:00]]
        )

      {1, _} =
        Claper.Repo.update_all(
          Ecto.Query.from(l in Log, where: l.id == ^newer.id),
          set: [inserted_at: ~N[2026-01-02 10:00:00]]
        )

      {logs, meta} = Audit.list_logs_for_user(user)

      ids = Enum.map(logs, & &1.id)
      assert ids == [newer.id, older.id]
      assert Enum.all?(logs, &(&1.user_id == user.id))
      assert meta.total_count == 2
    end

    test "list_logs_for_user/2 accepts a user id and paginates" do
      user = user_fixture()

      for index <- 1..3 do
        log_fixture(%{user_id: user.id, action: "user.action.#{index}"})
      end

      {logs, meta} = Audit.list_logs_for_user(user.id, %{"page" => 1, "page_size" => 2})

      assert length(logs) == 2
      assert meta.total_count == 3
      assert meta.total_pages == 2
    end

    test "list_action_types/0 returns distinct action types" do
      log_fixture(%{action: "user.login"})
      log_fixture(%{action: "user.login"})
      log_fixture(%{action: "event.create"})

      action_types = Audit.list_action_types()
      assert "user.login" in action_types
      assert "event.create" in action_types
      assert Enum.count(action_types, &(&1 == "user.login")) == 1
      assert Enum.count(action_types, &(&1 == "event.create")) == 1
    end
  end
end
