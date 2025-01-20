defmodule Ocrlot.Orchestractor do
  alias Phoenix.PubSub

  alias Ocrlot.Converter.Payload, as: ConverterPayload
  alias Ocrlot.Converter.Result, as: ConverterResult

  alias Ocrlot.Extractor.Payload, as: ExtractorPayload
  alias Ocrlot.Extractor.Result, as: ExtractorResult

  def pdf_to_text(filepath) do
    file_id =
      :crypto.hash(:sha256, filepath)
      |> Base.decode16(case: :lower)

    temp_folder = System.tmp_dir!()

    converter_in = "in:#{Ocrlot.Converter}:#{file_id}"
    extractor_in = "in:#{Ocrlot.Extractor}:#{file_id}"
    extractor_out = "out:#{Ocrlot.Extractor}:#{file_id}"

    converter_to_extractor = fn {%ConverterResult{} = result, metadata} ->
      message = %ExtractorPayload{
        filepath: result.filepath,
        languages: ["por"]
      }

      metadata = Map.put(metadata, :page_number, result.page_number)

      {:process, message, metadata}
    end

    extractor_to_result = fn {%ExtractorResult{} = result, metadata} ->
      {:extractor_output, result.content, metadata.page_number}
    end

    {:ok, _} =
      Ocrlot.Converter.start_link(%Ocrlot.Converter.Args{
        in: converter_in,
        out: extractor_in,
        mapper: converter_to_extractor
      })

    {:ok, _} =
      Ocrlot.Extractor.start_link(%Ocrlot.Extractor.Args{
        in: extractor_in,
        out: extractor_out,
        mapper: extractor_to_result
      })

    PubSub.subscribe(Ocrlot.PubSub, extractor_out)

    payload = %ConverterPayload{
      filepath: filepath,
      output_folder: temp_folder
    }

    PubSub.broadcast(Ocrlot.PubSub, converter_in, {:process, payload, %{}})

    {:ok, file_info} = Ocrlot.Converter.get_file_info(filepath)

    await(file_info.total_pages)
    |> Enum.sort_by(fn {page_number, _} -> page_number end)
  end

  def await(total_items, results \\ [])

  def await(total_items, results) when total_items > 0 do
    receive do
      {:extractor_output, content, page_number} ->
        item = {page_number, content}
        await(total_items - 1, [item | results])

      _ ->
        await(total_items, results)
    end
  end

  def await(_, results), do: results
end
