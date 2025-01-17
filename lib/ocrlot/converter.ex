defmodule Ocrlot.Converter do
  def identify_pdf(filepath) do
    {result_str, 0} =
      System.cmd("pdfinfo", [
        filepath
      ])

    [_, total_pages] = Regex.run(~r/Pages:\s+(\d+)/, result_str)

    info = %{
      original_filepath: filepath,
      total_pages: String.to_integer(total_pages)
    }

    {:ok, info}
  end

  def pdf_to_image(filepath, output_folder) do
    if !File.dir?(output_folder) do
      File.mkdir!(output_folder)
    end

    {:ok, file_info} = identify_pdf(filepath)

    Enum.map(0..(file_info.total_pages - 1), fn page_idx ->
      page_idx_str = Integer.to_string(page_idx)
      output_path = Path.join(output_folder, page_idx_str)

      opts = [
        "-singlefile",
        "-f",
        page_idx_str,
        "-r",
        "300",
        "-jpeg",
        "-jpegopt",
        "quality=100",
        filepath,
        output_path
      ]

      Task.Supervisor.async(
        Ocrlot.Converter.TaskSupervisor,
        fn ->
          {_, 0} = System.cmd("pdftoppm", opts)
          {:ok, "#{output_path}.jpg"}
        end
      )
    end)
    |> Task.await_many(30_000)
  end

  """
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

      {_, 0} = System.cmd("convert", opts)

      {:ok, output_path}
    end
  """
end
