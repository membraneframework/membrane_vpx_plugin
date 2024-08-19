defmodule Membrane.VP9.Encoder do
  @moduledoc """
  Element that encodes a VP9 stream.

  This element can receive a `Membrane.KeyframeRequestEvent` on it's `:output` pad to force the
  next frame to be a keyframe.

  Buffers produced by this element will have the following metadata that inform whether the buffer
  contains a keyframe:
  ```elixir
  %{vp9: %{is_keyframe: is_keyframe :: boolean()}}
  ```
  """
  use Membrane.Filter

  alias Membrane.{VP9, VPx}

  def_options encoding_deadline: [
                spec: Membrane.Time.t() | :auto,
                default: :auto,
                description: """
                Determines how long should it take the encoder to encode a frame.
                The longer the encoding takes the better the quality will be. If set to 0 the
                encoder will take as long as it needs to produce the best frame possible. Note that
                this is a soft limit, there is no guarantee that the encoding process will never exceed it.
                If set to `:auto` the deadline will be calculated based on the framerate provided by
                incoming stream format. If the framerate is `nil` a fixed deadline of 10ms will be set.
                """
              ],
              rc_target_bitrate: [
                spec: pos_integer() | :auto,
                default: :auto,
                description: """
                Gives the encoder information about the target bitrate (in kb/s). If set to `:auto`
                the target bitrate will be calculated automatically based on the resolution and framerate
                of the incoming stream. Some reference recommended bitrates can be also found
                [here](https://support.google.com/youtube/answer/1722171#zippy=%2Cbitrate)
                """
              ],
              g_lag_in_frames: [
                spec: non_neg_integer(),
                default: 5,
                description: """
                The number of input frames the encoder is allowed to consume
                before producing output frames. This allows the encoder to
                base decisions for the current frame on future frames. This does
                increase the latency of the encoding pipeline, so it is not appropriate
                in all situations (ex: realtime encoding).

                Note that this is a maximum value -- the encoder may produce frames
                sooner than the given limit. If set to 0 this feature will be disabled.
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
  defdelegate handle_event(pad, event, ctx, state), to: VPx.Encoder

  @impl true
  defdelegate handle_end_of_stream(pad, ctx, state), to: VPx.Encoder
end
