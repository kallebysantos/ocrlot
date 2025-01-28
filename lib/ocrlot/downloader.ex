defmodule Ocrlot.Downloader do
  # Downloas and returns the raw response body
  def donwload(file_url, opts \\ []) do
    headers = Keyword.get(opts, :headers, [])
    insecure = Keyword.get(opts, :insecure)

    request_opts = []

    # Add insecure option for hackney if provided
    request_opts =
      if insecure, do: Keyword.put(request_opts, :hackney, [:insecure]), else: request_opts

    case HTTPoison.get(file_url, headers, request_opts) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        # TODO: validate {"Content-Type", "application/pdf"}
        {:ok, body}

      error ->
        error
    end
  end

  def get_file(command, opts \\ [])

  def get_file({:base64, _file_url}, _opts), do: {:error, :not_implemented}

  def get_file(file_url, opts) do
    with {:ok, file_bytes} <- donwload(file_url, opts),
         {:ok, file_prefix} <- get_url_hash(file_url),
         {:ok, file_path} <- Plug.Upload.random_file(file_prefix),
         :ok <- File.write(file_path, file_bytes) do
      {:ok, file_path}
    end
  end

  def get_url_hash(url) do
    url_hash =
      :crypto.hash(:sha256, url)
      |> Base.encode16(case: :lower)

    {:ok, url_hash}
  end
end
