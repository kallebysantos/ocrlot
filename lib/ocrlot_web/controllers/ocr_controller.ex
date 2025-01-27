defmodule OcrlotWeb.OcrController do
  use OcrlotWeb, :controller

  def handle_process(conn, params) do
    if download_url = params["url"] do
      with {:ok, _} <- URI.new(download_url),
           {:ok, filepath} <- Ocrlot.Downloader.get_file({:bytes, download_url}) do
        pages =
          Ocrlot.Orchestractor.pdf_to_text(filepath)
          |> Enum.map(fn {page, idx} -> %{page: page, index: idx} end)

        json(conn, %{"content" => pages})
      end
    else
      json(conn, %{"message" => "missing file url"})
    end
  end
end
