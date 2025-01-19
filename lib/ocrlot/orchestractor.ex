defmodule Ocrlot.Orchestractor do
  alias Hex.Solver.Constraints.Empty
  alias Ocrlot.Extractor
  alias Ocrlot.Extractor.Worker.Payload, as: ExtractorPayload

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
        |> Stream.map(&elem(&1, 1))
        |> Enum.with_index()
        |> extract_pages()
        |> Enum.sort_by(fn {_, index} -> index end, :asc)
      end)

    # seconds
    extraction_time = extraction_time / 1_000_000

    IO.puts(
      "#{extraction_time}s extracted: #{filepath} total of #{Enum.count(converted_pages)} pages."
    )

    IO.puts("Total time: #{conversion_time + extraction_time}s")

    extracted_texts
  end

  defp extract_pages(pages, results \\ [])

  defp extract_pages(pages, results) when pages != [] do
    take = fn
      {cb, pages, :ok, worker, tasks} when pages != [] ->
        [{page, index} | pages] = pages

        task =
          Task.Supervisor.async(Ocrlot.Converter.TaskSupervisor, fn ->
            {:ok, content} =
              Extractor.Worker.process(worker, %ExtractorPayload{
                filepath: page,
                languages: ["por"]
              })

            {content, index}
          end)

        if pages !== [] do
          {status, value} = Ocrlot.Extractor.WorkerPool.start_child()

          cb.({cb, pages, status, value, [task | tasks]})
        else
          {pages, tasks}
        end

      {_cb, pages, _status, _value, tasks} ->
        {pages, tasks}
    end

    {status, value} = Ocrlot.Extractor.WorkerPool.start_child() |> dbg()

    {pages, tasks} =
      take.({take, pages, status, value, []})

    results = results ++ Task.await_many(tasks, 10_000)
    # dbg()

    extract_pages(pages, results)
  end

  defp extract_pages(pages, results) when length(pages) === 0,
    # |> dbg()
    do: results
end

# converted_pages
# |> Enum.take(Extractor.WorkerPool.max_children())
# |> Enum.map(fn {_, image_path} ->
#   # TODO: improve async with worker queue
#   Task.Supervisor.async(Ocrlot.Converter.TaskSupervisor, fn ->
#     case Extractor.WorkerPool.start_child() |> dbg() do
#       {:ok, pid} ->
#         Extractor.Worker.process(pid, %ExtractorPayload{
#           filepath: image_path,
#           languages: ["por"]
#         })
# 
#       {:error, reason} ->
#         IO.inspect(reason)
#     end
#   end)
# end)
# |> Task.await_many(30_000)
