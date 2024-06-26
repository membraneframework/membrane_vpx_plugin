defmodule Membrane.VP9.Encoder do
  @moduledoc """
  Element that encodes a VP9 stream
  """
  use Membrane.Filter

  alias Membrane.{VP9, VPx}

  def_options encoding_deadline: [
                spec: non_neg_integer(),
                default: 1,
                description: """
                Determines how long should it take the encoder to encode a frame (in microseconds).
                The longer the encoding takes the better the quality will be. If set to 0 the
                encoder will take as long as it needs to produce the best frame possible. Note that
                this is a soft limit, there is no guarantee that the encoding process will never exceed it.
                """
              ]

  def_input_pad :input,
    accepted_format: Membrane.RawVideo

  def_output_pad :output,
    accepted_format: VP9

  @impl true
  def handle_init(ctx, opts) do
    VPx.Encoder.handle_init(ctx, opts, :vp9)
  end

  @impl true
  defdelegate handle_stream_format(pad, stream_format, ctx, state), to: VPx.Encoder

  @impl true
  defdelegate handle_buffer(pad, buffer, ctx, state), to: VPx.Encoder

  @impl true
  defdelegate handle_end_of_stream(pad, ctx, state), to: VPx.Encoder
end
