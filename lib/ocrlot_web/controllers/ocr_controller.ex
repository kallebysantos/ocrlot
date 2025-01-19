defmodule OcrlotWeb.OcrController do
  use OcrlotWeb, :controller

  def handle_process(conn, params) do
    if file = params["file"] do
      if file.content_type === "application/pdf" do
        pages =
          Ocrlot.Orchestractor.pdf_to_text(file.path)
          |> Enum.map(fn {page, idx} -> %{page: page, index: idx} end)

        json(conn, %{"content" => pages})
      else
        json(conn, %{"message" => "wrong file type"})
      end
    else
      json(conn, %{"message" => "missing file"})
    end
  end
end
