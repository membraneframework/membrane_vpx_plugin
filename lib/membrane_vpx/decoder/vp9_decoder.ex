defmodule Membrane.VP9.Decoder do
  @moduledoc """
  Element that decodes a VP9 stream
  """
  use Membrane.Filter

  alias Membrane.{VP9, VPx}

  def_input_pad :input,
    accepted_format:
      any_of(VP9, %Membrane.RemoteStream{content_format: format} when format in [nil, VP9])

  def_output_pad :output,
    accepted_format: Membrane.RawVideo

  @impl true
  def handle_init(ctx, opts) do
    VPx.Decoder.handle_init(ctx, opts, :vp9)
  end

  @impl true
  defdelegate handle_setup(ctx, state), to: VPx.Decoder

  @impl true
  defdelegate handle_stream_format(pad, stream_format, ctx, state), to: VPx.Decoder

  @impl true
  defdelegate handle_buffer(pad, buffer, ctx, state), to: VPx.Decoder
end
