defmodule Membrane.VP8.Encoder do
  @moduledoc """
  Element that encodes a VP8 stream
  """
  use Membrane.Filter

  alias Membrane.{VP8, VPx}

  def_options real_time: [
                spec: boolean(),
                default: true
              ]

  def_input_pad :input,
    accepted_format: Membrane.RawVideo

  def_output_pad :output,
    accepted_format: VP8

  @impl true
  def handle_init(ctx, opts) do
    VPx.Encoder.handle_init(ctx, opts, :vp8)
  end

  @impl true
  defdelegate handle_stream_format(pad, stream_format, ctx, state), to: VPx.Encoder

  @impl true
  defdelegate handle_buffer(pad, buffer, ctx, state), to: VPx.Encoder
end
