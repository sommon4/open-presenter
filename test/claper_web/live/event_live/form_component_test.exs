defmodule ClaperWeb.EventLive.FormComponentTest do
  use ClaperWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  import Claper.{AccountsFixtures, FormsFixtures, PresentationsFixtures}

  alias ClaperWeb.EventLive.FormComponent

  defp setup_form(field_attrs) do
    presentation_file = presentation_file_fixture(%{}, [:event])

    form =
      form_fixture(%{
        presentation_file_id: presentation_file.id,
        fields: field_attrs
      })

    %{event: presentation_file.event, form: form}
  end

  describe "rendering fields with non-alphanumeric names" do
    test "renders an input whose name uses the original field name (with spaces)" do
      %{event: event, form: form} =
        setup_form([
          %{name: "First Name", type: "text", required: false},
          %{name: "Email Address", type: "email", required: false}
        ])

      html =
        render_component(FormComponent,
          id: "form-component",
          form: form,
          current_user: user_fixture(),
          attendee_identifier: nil,
          event: event,
          current_form_submit: nil
        )

      # The HTML name attribute must contain the actual field name —
      # regression: a previous version mapped any non-\w name to :invalid_field,
      # so all space-containing fields collided on `form_submit[invalid_field]`
      # and submissions were saved under the wrong key.
      assert html =~ ~s(name="form_submit[First Name]")
      assert html =~ ~s(name="form_submit[Email Address]")
      refute html =~ "invalid_field"
    end

    test "preserves submitted values when re-rendering for fields with spaces" do
      %{event: event, form: form} =
        setup_form([
          %{name: "First Name", type: "text", required: false}
        ])

      form_submit = %Claper.Forms.FormSubmit{
        response: %{"First Name" => "Ada"}
      }

      html =
        render_component(FormComponent,
          id: "form-component",
          form: form,
          current_user: user_fixture(),
          attendee_identifier: nil,
          event: event,
          current_form_submit: form_submit
        )

      assert html =~ ~s(value="Ada")
    end
  end
end
