defmodule Membrane.VPx.Encoder.Native do
  @moduledoc false
  use Unifex.Loader

  @spec create!(
          :vp8 | :vp9,
          pos_integer(),
          pos_integer(),
          Membrane.RawVideo.pixel_format(),
          non_neg_integer(),
          non_neg_integer(),
          Membrane.VPx.Encoder.user_encoder_config()
        ) :: reference()
  def create!(
        codec,
        width,
        height,
        pixel_format,
        encoding_deadline,
        cpu_used,
        user_encoder_config
      ) do
    case create(
           codec,
           width,
           height,
           pixel_format,
           encoding_deadline,
           cpu_used,
           user_encoder_config
         ) do
      {:ok, decoder_ref} -> decoder_ref
      {:error, reason} -> raise "Failed to create native encoder: #{inspect(reason)}"
    end
  end
end
