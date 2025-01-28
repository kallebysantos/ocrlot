defmodule OcrlotWeb.OcrController do
  use OcrlotWeb, :controller

  def handle_process(conn, params) do
    with {:ok, command, options} <- parse_params(params),
         {:ok, filepath} <- Ocrlot.Downloader.get_file(command, options) do
      pages =
        Ocrlot.Orchestractor.pdf_to_text(filepath)
        |> Enum.map(fn {idx, content} -> %{content: content, page: idx} end)

      json(conn, %{"content" => pages})
    else
      error -> json(conn, %{"error" => error})
    end
  end

  def parse_params(params) do
    case Map.fetch(params, "url") do
      :error ->
        {:error, :missing_url}

      {:ok, url} ->
        execution_opts = []

        options = Map.get(params, "options", %{})
        insecure = Map.get(options, "insecure", false)

        # Add insecure option
        execution_opts =
          if insecure,
            do: Keyword.put(execution_opts, :insecure, insecure),
            else: execution_opts

        if Map.get(options, "document_type") === "base64" do
          {:ok, {:base64, url}, execution_opts}
        else
          {:ok, url, execution_opts}
        end
    end
  end
end
