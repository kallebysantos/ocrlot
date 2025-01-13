defmodule Ocrlot.Converter do
  def identify_pdf(filepath) do
    {result_str, 0} =
      System.cmd("magick", [
        "identify",
        "-format",
        "%d/%f[%p]\r\n",
        filepath
      ])

    pages = String.split(result_str)

    info = %{
      original_filepath: filepath,
      total_pages: Enum.count(pages),
      pages: pages
    }

    {:ok, info}
  end

  def pdf_to_image(filepath, output_folder) do
    if !File.dir?(output_folder) do
      File.mkdir!(output_folder)
    end

    {:ok, file_info} = identify_pdf(filepath)

    file_info.pages
    |> Stream.with_index()
    |> Stream.map(fn {page, idx} -> {page, Path.join(output_folder, "#{idx}.jpeg")} end)
    |> Enum.each(&convert_async/1)
  end

  def convert_async(opts) do
    Task.Supervisor.start_child(
      Ocrlot.Converter.TaskSupervisor,
      fn -> convert(opts) end
    )
  end

  def convert({input_file, output_path}) do
    opts = [
      "-density",
      "300",
      input_file,
      "-alpha",
      "remove",
      "-background",
      "white",
      output_path
    ]

    {_, 0} = System.cmd("magick", opts)

    :ok
  end
end
