defmodule Claper.Tasks.ConverterTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Claper.Presentations.PresentationFile
  alias Claper.Tasks.Converter

  test "uses the available Req client for S3 requests" do
    assert Application.fetch_env!(:ex_aws, :http_client) == ExAws.Request.Req
    assert Code.ensure_loaded?(ExAws.Request.Req)
    assert function_exported?(ExAws.Request.Req, :request, 5)
  end

  describe "regenerate_thumbnails/1" do
    test "uses convert when magick is unavailable" do
      storage_dir = unique_tmp_dir()
      hash = "convert-fallback"
      slide_dir = Path.join([storage_dir, "uploads", hash])
      bin_dir = Path.join(storage_dir, "bin")

      File.mkdir_p!(slide_dir)
      File.write!(Path.join(slide_dir, "1.jpg"), "slide")
      File.mkdir_p!(bin_dir)
      write_fake_imagemagick(bin_dir, "convert")

      put_local_storage_config(storage_dir)
      put_path(bin_dir)

      presentation_file = %PresentationFile{hash: hash, length: 1}

      output =
        capture_io(fn -> assert :ok = Converter.regenerate_thumbnails(presentation_file) end)

      assert output =~ "Generated 1 thumbnails"
      assert File.read!(Path.join([slide_dir, "thumbs", "1.jpg"])) == "fake-thumbnail"
    end

    test "returns a clear error when ImageMagick is unavailable" do
      storage_dir = unique_tmp_dir()
      hash = "missing-imagemagick"
      slide_dir = Path.join([storage_dir, "uploads", hash])
      empty_bin_dir = Path.join(storage_dir, "empty-bin")

      File.mkdir_p!(slide_dir)
      File.write!(Path.join(slide_dir, "1.jpg"), "slide")
      File.mkdir_p!(empty_bin_dir)

      put_local_storage_config(storage_dir)
      put_path(empty_bin_dir)

      assert {:error, :missing_imagemagick} =
               Converter.regenerate_thumbnails(%PresentationFile{hash: hash, length: 1})
    end
  end

  defp write_fake_imagemagick(bin_dir, command) do
    path = Path.join(bin_dir, command)

    File.write!(path, """
    #!/bin/sh
    last=""

    for arg in "$@"; do
      last="$arg"
    done

    printf fake-thumbnail > "$last"
    """)

    File.chmod!(path, 0o755)
  end

  defp put_local_storage_config(storage_dir) do
    previous_storage_dir = Application.get_env(:claper, :storage_dir)
    previous_presentations = Application.get_env(:claper, :presentations)

    Application.put_env(:claper, :storage_dir, storage_dir)

    Application.put_env(
      :claper,
      :presentations,
      Keyword.merge(previous_presentations || [], storage: "local")
    )

    on_exit(fn ->
      File.rm_rf!(storage_dir)
      Application.put_env(:claper, :storage_dir, previous_storage_dir)
      Application.put_env(:claper, :presentations, previous_presentations)
    end)
  end

  defp put_path(path) do
    previous_path = System.get_env("PATH")

    System.put_env("PATH", path)

    on_exit(fn ->
      if previous_path do
        System.put_env("PATH", previous_path)
      else
        System.delete_env("PATH")
      end
    end)
  end

  defp unique_tmp_dir do
    Path.join(System.tmp_dir!(), "claper-converter-test-#{System.unique_integer([:positive])}")
  end
end
