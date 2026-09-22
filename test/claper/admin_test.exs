defmodule Claper.AdminTest do
  use Claper.DataCase

  alias Claper.Admin
  alias Claper.Accounts.User
  alias Claper.Repo

  import Claper.AccountsFixtures
  import Claper.EventsFixtures

  describe "list_users_paginated/1" do
    test "returns paginated users" do
      search = "admin-pagination-user"

      users =
        for index <- 1..21 do
          user_fixture(%{email: "#{search}-#{index}@example.com"})
        end

      {page_1_users, meta_1} =
        Admin.list_users_paginated(%{
          "page" => 1,
          "page_size" => 20,
          "order_by" => ["email"],
          "order_directions" => ["asc"],
          "filters" => [%{"field" => "email", "op" => "ilike_or", "value" => search}]
        })

      {page_2_users, meta_2} =
        Admin.list_users_paginated(%{
          "page" => 2,
          "page_size" => 20,
          "order_by" => ["email"],
          "order_directions" => ["asc"],
          "filters" => [%{"field" => "email", "op" => "ilike_or", "value" => search}]
        })

      assert meta_1.total_count == 21
      assert meta_1.total_pages == 2
      assert meta_2.total_count == 21
      assert meta_2.total_pages == 2
      assert length(page_1_users) == 20
      assert length(page_2_users) == 1

      expected_user_ids =
        users
        |> Enum.sort_by(& &1.email, :asc)
        |> Enum.map(& &1.id)

      assert Enum.map(page_1_users ++ page_2_users, & &1.id) == expected_user_ids
    end
  end

  describe "list_events_paginated/1" do
    test "returns paginated events" do
      search = "admin-pagination-event"

      events =
        for index <- 1..21 do
          event_fixture(%{
            name: "#{search} #{index}",
            started_at: NaiveDateTime.add(~N[2026-01-01 00:00:00], index, :second)
          })
        end

      {page_1_events, meta_1} =
        Admin.list_events_paginated(%{
          "page" => 1,
          "page_size" => 20,
          "filters" => [%{"field" => "name", "op" => "ilike_or", "value" => search}]
        })

      {page_2_events, meta_2} =
        Admin.list_events_paginated(%{
          "page" => 2,
          "page_size" => 20,
          "filters" => [%{"field" => "name", "op" => "ilike_or", "value" => search}]
        })

      assert meta_1.total_count == 21
      assert meta_1.total_pages == 2
      assert meta_2.total_count == 21
      assert meta_2.total_pages == 2
      assert length(page_1_events) == 20
      assert length(page_2_events) == 1

      expected_event_ids =
        events
        |> Enum.sort_by(& &1.started_at, {:desc, NaiveDateTime})
        |> Enum.map(& &1.id)

      assert Enum.map(page_1_events ++ page_2_events, & &1.id) == expected_event_ids
    end
  end

  describe "get_growth_metrics/0" do
    test "returns numeric negative growth for users when the current month declines" do
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      fifteen_days_ago = NaiveDateTime.add(now, -(15 * 24 * 60 * 60), :second)
      forty_five_days_ago = NaiveDateTime.add(now, -(45 * 24 * 60 * 60), :second)
      ninety_days_ago = NaiveDateTime.add(now, -(90 * 24 * 60 * 60), :second)

      Repo.update_all(User, set: [inserted_at: ninety_days_ago, updated_at: ninety_days_ago])

      previous_users =
        for index <- 1..2 do
          user_fixture(%{email: "growth-previous-#{index}@example.com"})
        end

      current_user = user_fixture(%{email: "growth-current@example.com"})

      Repo.update_all(
        from(u in User, where: u.id in ^Enum.map(previous_users, & &1.id)),
        set: [inserted_at: forty_five_days_ago, updated_at: forty_five_days_ago]
      )

      Repo.update_all(
        from(u in User, where: u.id == ^current_user.id),
        set: [inserted_at: fifteen_days_ago, updated_at: fifteen_days_ago]
      )

      assert %{users_growth: users_growth} = Admin.get_growth_metrics()
      assert is_float(users_growth)
      assert users_growth < 0
    end
  end
end
