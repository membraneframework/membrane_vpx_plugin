defmodule Membrane.VP8.Decoder do
  @moduledoc """
  Element that decodes a VP8 stream
  """
  use Membrane.Filter

  alias Membrane.{VP8, VPx}

  def_options width: [
                spec: non_neg_integer() | nil,
                default: nil,
                description: """
                Width of a frame, if not provided an attempt will be made to get it from stream format. In case that fails the element will crash.
                """
              ],
              height: [
                spec: non_neg_integer() | nil,
                default: nil,
                description: """
                Height of a frame, if not provided an attempt will be made to get it from stream format. In case that fails the element will crash.
                """
              ],
              framerate: [
                spec: {non_neg_integer(), pos_integer()} | nil,
                default: nil,
                description: """
                Framerate, if not provided an attempt will be made to get it from stream format. In case that fails the element will crash.
                """
              ]

  def_input_pad :input,
    accepted_format:
      any_of(VP8, %Membrane.RemoteStream{content_format: format} when format in [nil, VP8])

  def_output_pad :output,
    accepted_format: Membrane.RawVideo

  @impl true
  def handle_init(ctx, opts) do
    VPx.Decoder.handle_init(ctx, opts, :vp8)
  end

  @impl true
  defdelegate handle_setup(ctx, state), to: VPx.Decoder

  @impl true
  defdelegate handle_stream_format(pad, stream_format, ctx, state), to: VPx.Decoder

  @impl true
  defdelegate handle_buffer(pad, buffer, ctx, state), to: VPx.Decoder
end