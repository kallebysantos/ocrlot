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

  def get_file({:base64, file_url}, opts) do
    with {:ok, base64_encoded} <- donwload(file_url, opts),
         {:ok, file_prefix} <- get_url_hash(file_url),
         {:ok, file_path} <- Plug.Upload.random_file(file_prefix),
         {:ok, file_bytes} <- decode_base64(base64_encoded),
         :ok <- File.write(file_path, file_bytes) do
      {:ok, file_path}
    end
  end

  def get_file(file_url, opts) do
    with {:ok, file_bytes} <- donwload(file_url, opts),
         {:ok, file_prefix} <- get_url_hash(file_url),
         {:ok, file_path} <- Plug.Upload.random_file(file_prefix),
         :ok <- File.write(file_path, file_bytes) do
      {:ok, file_path}
    end
  end

  def decode_base64(encoded) do
    encoded =
      encoded
      |> String.normalize(:nfkc)
      |> String.replace("\"", "")
      |> String.trim()

    case Base.decode64(encoded) do
      {:ok, file_bytes} ->
        {:ok, file_bytes}

      :error ->
        {:error, :invalid_base64}
    end
  end

  def get_url_hash(url) do
    url_hash =
      :crypto.hash(:sha256, url)
      |> Base.encode16(case: :lower)

    {:ok, url_hash}
  end
end
