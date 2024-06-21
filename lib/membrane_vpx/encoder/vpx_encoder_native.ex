defmodule Membrane.VPx.Encoder.Native do
  @moduledoc false
  use Unifex.Loader

  alias Membrane.RawVideo

  @spec create!(:vp8 | :vp9, non_neg_integer(), non_neg_integer(), RawVideo.pixel_format()) ::
          reference()
  def create!(codec, width, height, pixel_format) do
    case create(codec, width, height, pixel_format) do
      {:ok, decoder_ref} -> decoder_ref
      {:error, reason} -> raise "Failed to create native encoder: #{inspect(reason)}"
    end
  end
end
