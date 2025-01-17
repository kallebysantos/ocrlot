defmodule Ocrlot.Extractor do
  def img_to_text(image_filepath, langs, _opts \\ []) do
    opts = [
      image_filepath,
      "-",
      "-l",
      Enum.join(langs, "+"),
      "quiet",
      "-psm",
      "6"
    ]

    {text, 0} = System.cmd("tesseract", opts)

    {:ok, text}
  end
end
