defmodule ClaperWeb.EventLive.ManageAudienceResponsesComponent do
  @moduledoc false
  use Phoenix.Component
  use Gettext, backend: ClaperWeb.Gettext

  @avatars ~w(🦊 🐙 🦉 🐸 🐼 🦋 🐬 🦈 🐢 🦎 🐝 🦩 🐧 🦦 🐨 🦁 🐯 🐻 🐰 🐮
    🐷 🐵 🦄 🐺 🦇 🐳 🐠 🦑 🦞 🦀 🐡 🐞 🦗 🕷 🦂 🐍 🦕 🦖 🦚 🦜
    🦢 🦩 🐓 🦃 🦆 🦅 🦔 🐿 🦫 🦨 🦡 🦝 🦥 🦘 🦙 🐫 🐘 🦏 🦛 🐊
    🐅 🐆 🦓 🐃 🐂 🐄 🐎 🐖 🐑 🐐 🦌 🐕 🐈 🦮 🐁 🐀 🦔 🐲 🌵 🍄)

  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-2 border border-gray-200 rounded-2xl p-2 flex-1 overflow-hidden bg-gray-100">
      <div class="flex items-center gap-2">
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="24"
          height="24"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
          class="icon icon-tabler icons-tabler-outline icon-tabler-message shrink-0 text-[#140553]"
        >
          <path stroke="none" d="M0 0h24v24H0z" fill="none" />
          <path d="M8 9h8" />
          <path d="M8 13h6" />
          <path d="M18 4a3 3 0 0 1 3 3v8a3 3 0 0 1 -3 3h-5l-5 3v-3h-2a3 3 0 0 1 -3 -3v-8a3 3 0 0 1 3 -3h12" />
        </svg>
        <span class="font-bold text-sm text-[#140553]">{gettext("Audience Responses")}</span>
      </div>
      
    <!-- Tabs -->
      <ul id="menu" phx-update="replace" class="flex items-center gap-x-1 overflow-x-auto">
        <li>
          <button
            phx-click="list-tab"
            phx-value-tab="posts"
            class={"px-3 py-1.5 rounded-full text-sm font-medium transition-colors #{if @list_tab == :posts, do: "bg-secondary-500 text-white", else: "text-gray-600 hover:bg-gray-100"}"}
          >
            {gettext("Messages")} ({@post_count})
          </button>
        </li>
        <li>
          <button
            phx-click="list-tab"
            phx-value-tab="questions"
            class={"px-3 py-1.5 rounded-full text-sm font-medium transition-colors #{if @list_tab == :questions, do: "bg-secondary-500 text-white", else: "text-gray-600 hover:bg-gray-100"}"}
          >
            {gettext("Questions")} ({@question_count})
          </button>
        </li>
        <li>
          <button
            phx-click="list-tab"
            phx-value-tab="pinned_posts"
            class={"px-3 py-1.5 rounded-full text-sm font-medium transition-colors #{if @list_tab == :pinned_posts, do: "bg-secondary-500 text-white", else: "text-gray-600 hover:bg-gray-100"}"}
          >
            {gettext("Pinned")} ({@pinned_post_count})
          </button>
        </li>
        <li>
          <button
            phx-click="list-tab"
            phx-value-tab="forms"
            class={"px-3 py-1.5 rounded-full text-sm font-medium transition-colors #{if @list_tab == :forms, do: "bg-secondary-500 text-white", else: "text-gray-600 hover:bg-gray-100"}"}
          >
            {gettext("Forms")} ({@form_submit_count})
          </button>
        </li>
      </ul>
      
    <!-- Tab Content -->
      <div class="flex-1 overflow-y-auto overflow-x-hidden">
        <%= if @list_tab == :posts do %>
          <div
            :if={@post_count == 0}
            class="h-full flex flex-col items-center justify-center text-gray-400 py-8"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-12 w-12 mb-3"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="1.5"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M17 8h2a2 2 0 012 2v6a2 2 0 01-2 2h-2v4l-4-4H9a1.994 1.994 0 01-1.414-.586m0 0L11 14h4a2 2 0 002-2V6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2v4l.586-.586z"
              />
            </svg>
            <p class="text-sm">{gettext("Messages from attendees will appear here.")}</p>
          </div>
          <div :if={@post_count > 0} id="post-list" class="p-2 space-y-3" phx-update="stream">
            <.live_component
              :for={{id, post} <- @streams.posts}
              module={ClaperWeb.EventLive.ManageablePostComponent}
              id={id}
              event={@event}
              post={post}
            />
          </div>
        <% end %>

        <%= if @list_tab == :questions do %>
          <div
            :if={@question_count == 0}
            class="h-full flex flex-col items-center justify-center text-gray-400 py-8"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="1.5"
              stroke="currentColor"
              class="w-12 h-12 mb-3"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M9.879 7.519c1.171-1.025 3.071-1.025 4.242 0 1.172 1.025 1.172 2.687 0 3.712-.203.179-.43.326-.67.442-.745.361-1.45.999-1.45 1.827v.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Zm-9 5.25h.008v.008H12v-.008Z"
              />
            </svg>
            <p class="text-sm">{gettext("Questions will appear here.")}</p>
          </div>
          <div :if={@question_count > 0} class="flex flex-col h-full">
            <div class="px-2 py-2 flex items-center gap-x-2">
              <span class="text-xs text-gray-500">{gettext("Sort by:")}</span>
              <div class="tooltip tooltip-bottom" data-tip={gettext("Show newest questions first")}>
                <button
                  class="px-3 py-1 text-xs rounded-md bg-gray-100 text-gray-700 hover:bg-gray-200 flex items-center gap-x-1"
                  phx-click="sort-questions"
                  phx-value-sort="date"
                >
                  {gettext("Most recent")}
                </button>
              </div>
              <div
                class="tooltip tooltip-bottom"
                data-tip={gettext("Show most voted questions first")}
              >
                <button
                  class="px-3 py-1 text-xs rounded-md bg-gray-100 text-gray-700 hover:bg-gray-200 flex items-center gap-x-1"
                  phx-click="sort-questions"
                  phx-value-sort="likes"
                >
                  {gettext("Most popular")}
                </button>
              </div>
            </div>
            <div
              id="question-list"
              class="flex-1 overflow-y-auto overflow-x-hidden p-2 space-y-3"
              phx-update="stream"
            >
              <.live_component
                :for={{id, post} <- @streams.questions}
                module={ClaperWeb.EventLive.ManageablePostComponent}
                id={id}
                event={@event}
                post={post}
              />
            </div>
          </div>
        <% end %>

        <%= if @list_tab == :pinned_posts do %>
          <div
            :if={@pinned_post_count == 0}
            class="h-full flex flex-col items-center justify-center text-gray-400 py-8"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-12 w-12 mb-3"
              viewBox="0 0 24 24"
              stroke-width="1.5"
              stroke="currentColor"
              fill="none"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M15 4.5l-4 4l-4 1.5l-1.5 1.5l7 7l1.5 -1.5l1.5 -4l4 -4" /><path d="M9 15l-4.5 4.5" /><path d="M14.5 4l5.5 5.5" />
            </svg>
            <p class="text-sm">{gettext("Pinned messages will appear here.")}</p>
          </div>
          <div
            :if={@pinned_post_count > 0}
            id="pinned-post-list"
            class="p-2 space-y-3"
            phx-update="stream"
          >
            <.live_component
              :for={{id, post} <- @streams.pinned_posts}
              module={ClaperWeb.EventLive.ManageablePostComponent}
              id={id}
              event={@event}
              post={post}
            />
          </div>
        <% end %>

        <%= if @list_tab == :forms do %>
          <div
            :if={@form_submit_count == 0}
            class="h-full flex flex-col items-center justify-center text-gray-400 py-8"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-12 w-12 mb-3"
              viewBox="0 0 24 24"
              stroke-width="1.5"
              stroke="currentColor"
              fill="none"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <path stroke="none" d="M0 0h24v24H0z" fill="none"></path>
              <path d="M12 3a3 3 0 0 0 -3 3v12a3 3 0 0 0 3 3"></path>
              <path d="M6 3a3 3 0 0 1 3 3v12a3 3 0 0 1 -3 3"></path>
              <path d="M13 7h7a1 1 0 0 1 1 1v8a1 1 0 0 1 -1 1h-7"></path>
              <path d="M5 7h-1a1 1 0 0 0 -1 1v8a1 1 0 0 0 1 1h1"></path>
              <path d="M17 12h.01"></path>
              <path d="M13 12h.01"></path>
            </svg>
            <p class="text-sm">{gettext("Form submissions will appear here.")}</p>
          </div>
          <div
            id="form-list"
            class="p-2 space-y-3"
            phx-update="stream"
            data-forms-nb={@form_submit_count}
            phx-hook="ScrollIntoDiv"
          >
            <div
              :for={{id, submission} <- @streams.form_submits}
              id={id}
              class="group flex items-end gap-2"
            >
              <div class="flex shrink-0 flex-col items-center gap-1">
                <span class="text-xs leading-4 text-gray-400">
                  {Calendar.strftime(submission.inserted_at, "%H:%M")}
                </span>
                <div class="avatar avatar-placeholder">
                  <div
                    class="w-8 rounded-full text-white"
                    style={"background-color: #{avatar_color(submission)}"}
                  >
                    <span class="text-sm">{avatar_emoji(submission)}</span>
                  </div>
                </div>
              </div>

              <div class="flex min-w-0 flex-1 flex-col">
                <div class="mb-0.5 ml-3 flex min-h-5 items-center gap-2">
                  <span class="min-w-0 truncate text-sm font-bold text-secondary-500">
                    {submission.form.title}
                  </span>
                  <div class="ml-auto flex shrink-0 items-center divide-x divide-gray-200 rounded-lg border border-gray-200 opacity-0 transition-opacity group-hover:opacity-100">
                    <div class="tooltip tooltip-bottom" data-tip={gettext("Delete")}>
                      <button
                        type="button"
                        phx-click="delete-form-submit"
                        phx-value-id={submission.id}
                        data-confirm={gettext("This cannot be undone, confirm ?")}
                        aria-label={gettext("Delete")}
                        class="flex h-6 w-8 items-center justify-center text-error"
                      >
                        <svg
                          xmlns="http://www.w3.org/2000/svg"
                          width="24"
                          height="24"
                          viewBox="0 0 24 24"
                          fill="none"
                          stroke="currentColor"
                          stroke-width="2"
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          class="icon icon-tabler icons-tabler-outline icon-tabler-trash size-4"
                        >
                          <path stroke="none" d="M0 0h24v24H0z" fill="none" />
                          <path d="M4 7l16 0" />
                          <path d="M10 11l0 6" />
                          <path d="M14 11l0 6" />
                          <path d="M5 7l1 12a2 2 0 0 0 2 2h8a2 2 0 0 0 2 -2l1 -12" />
                          <path d="M9 7v-3a1 1 0 0 1 1 -1h4a1 1 0 0 1 1 1v3" />
                        </svg>
                      </button>
                    </div>
                  </div>
                </div>

                <div class="min-w-0 rounded-xl border border-base-200 bg-base-100 px-3 py-2 shadow-sm">
                  <dl class="divide-y divide-base-200">
                    <div :for={response <- submission.response} class="py-1.5 first:pt-0 last:pb-0">
                      <dt class="text-[11px] font-semibold leading-4 text-base-content/60">
                        {elem(response, 0)}
                      </dt>
                      <dd class="break-words text-xs leading-4 text-base-content">
                        {elem(response, 1)}
                      </dd>
                    </div>
                  </dl>
                </div>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp avatar_identifier(record) do
    "#{record.attendee_identifier || record.user_id || "default"}"
  end

  defp avatar_color(record) do
    hue = :erlang.phash2(avatar_identifier(record), 360)
    "hsl(#{hue}, 45%, 55%)"
  end

  defp avatar_emoji(record) do
    index = :erlang.phash2({avatar_identifier(record), :emoji}, length(@avatars))
    Enum.at(@avatars, index)
  end
end
