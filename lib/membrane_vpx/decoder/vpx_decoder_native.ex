defmodule Membrane.VPx.Decoder.Native do
  @moduledoc false
  use Unifex.Loader

  @spec create!(:vp8 | :vp9) :: reference()
  def create!(codec) do
    case create(codec) do
      {:ok, decoder_ref} -> decoder_ref
      {:error, reason} -> raise "Failed to create native decoder: #{inspect(reason)}"
    end
  end
end
