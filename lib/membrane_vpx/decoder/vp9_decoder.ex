defmodule Membrane.VP9.Decoder do
  @moduledoc """
  Element that decodes a VP9 stream
  """
  use Membrane.Filter

  alias Membrane.{VP9, VPx}

  def_options width: [
                spec: non_neg_integer() | nil,
                default: nil,
                description: """
                Width of a frame, needed if not provided with stream format. If it's not specified either in this option or the stream format, the element will crash.
                """
              ],
              height: [
                spec: non_neg_integer() | nil,
                default: nil,
                description: """
                Height of a frame, needed if not provided with stream format. If it's not specified either in this option or the stream format, the element will crash.
                """
              ],
              framerate: [
                spec: {non_neg_integer(), pos_integer()} | nil,
                default: nil,
                description: """
                Framerate of the stream.
                """
              ]

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
