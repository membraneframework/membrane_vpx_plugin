defmodule Membrane.VPx.Encoder.Native do
  @moduledoc false
  use Unifex.Loader

  @spec create!(:vp8 | :vp9, Membrane.VPx.Encoder.encoder_options()) :: reference()
  def create!(codec, encoder_options) do
    case create(codec, encoder_options) do
      {:ok, decoder_ref} -> decoder_ref
      {:error, reason} -> raise "Failed to create native encoder: #{inspect(reason)}"
    end
  end
end
