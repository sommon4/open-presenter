defmodule ClaperWeb.Office.ManifestController do
  @moduledoc """
  Serves the PowerPoint add-in manifest with this deployment's base URL, so
  no build-time URL substitution is needed. Users download it from
  `/office/manifest.xml` and sideload it (see docs/office-addin.md).
  """
  use ClaperWeb, :controller

  @template_path Application.app_dir(:claper, "priv/office/manifest.template.xml")
  @external_resource @template_path
  @template File.read!(@template_path)

  @default_id "5f2b4d0e-8c1a-4c6e-9a3b-0a4d6e7f8b91"

  def show(conn, _params) do
    base_url = String.trim_trailing(ClaperWeb.Endpoint.url(), "/")

    xml =
      @template
      |> String.replace("{{BASE_URL}}", base_url)
      |> String.replace("{{ADDIN_ID}}", addin_id())
      |> String.replace("{{VERSION}}", version())

    conn
    |> put_resp_content_type("application/xml")
    |> put_resp_header("content-disposition", ~s(attachment; filename="open-presenter.xml"))
    |> send_resp(200, xml)
  end

  defp addin_id do
    Application.get_env(:claper, :office_addin_id) || @default_id
  end

  defp version do
    vsn = Application.spec(:claper, :vsn) |> to_string()
    if Regex.match?(~r/^\d+\.\d+\.\d+$/, vsn), do: vsn <> ".0", else: "1.0.0.0"
  end
end
