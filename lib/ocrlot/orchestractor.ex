defmodule Ocrlot.Orchestractor do
  alias Ocrlot.ExtractorWorkerPool
  alias Ocrlot.Extractor.Payload, as: ExtractorPayload

  def pdf_to_text(filepath) do
    temp_folder = System.tmp_dir!()

    {conversion_time, converted_pages} =
      :timer.tc(Ocrlot.Converter, :pdf_to_image, [filepath, temp_folder])

    # seconds
    conversion_time = conversion_time / 1_000_000

    IO.puts(
      "#{conversion_time}s converted: #{filepath} total of #{Enum.count(converted_pages)} pages."
    )

    {extraction_time, extracted_texts} =
      :timer.tc(fn ->
        converted_pages
        |> Enum.map(fn {_, image_path} ->
          # TODO: improve async with worker queue
          Task.Supervisor.async(Ocrlot.Converter.TaskSupervisor, fn ->
            case ExtractorWorkerPool.start_child() do
              {:ok, pid} ->
                Ocrlot.Extractor.process(pid, %ExtractorPayload{
                  filepath: image_path,
                  languages: ["por"]
                })

              {:error, reason} ->
                IO.inspect(reason)
            end
          end)
        end)
        |> Task.await_many(30_000)
        |> Stream.map(&elem(&1, 1))
        |> Enum.with_index()
      end)

    # seconds
    extraction_time = extraction_time / 1_000_000

    IO.puts(
      "#{extraction_time}s extracted: #{filepath} total of #{Enum.count(converted_pages)} pages."
    )

    IO.puts("Total time: #{conversion_time + extraction_time}s")

    extracted_texts
  end
end
