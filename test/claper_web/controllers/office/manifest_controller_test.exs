defmodule ClaperWeb.Office.ManifestControllerTest do
  use ClaperWeb.ConnCase

  test "serves the add-in manifest with the deployment base URL", %{conn: conn} do
    conn = get(conn, ~p"/office/manifest.xml")
    body = response(conn, 200)
    assert response_content_type(conn, :xml) =~ "application/xml"
    base = String.trim_trailing(ClaperWeb.Endpoint.url(), "/")
    assert body =~ ~s(xsi:type="ContentApp")
    assert body =~ ~s(<SourceLocation DefaultValue="#{base}/office/index.html" />)
    assert body =~ ~s(<AppDomain>#{base}</AppDomain>)
    refute body =~ "{{"
    assert body =~ ~r/<Id>[0-9a-f-]{36}<\/Id>/
  end
end
