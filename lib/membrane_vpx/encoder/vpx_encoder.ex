defmodule Membrane.VPx.Encoder do
  @moduledoc false

  alias Membrane.{Buffer, DemandKeyframeEvent, RawVideo, VP8, VP9}
  alias Membrane.Element.CallbackContext
  alias Membrane.VPx.Encoder.Native

  @default_encoding_deadline Membrane.Time.milliseconds(10)

  defmodule State do
    @moduledoc false

    @type t :: %__MODULE__{
            codec: :vp8 | :vp9,
            codec_module: VP8 | VP9,
            encoding_deadline: non_neg_integer(),
            encoder_ref: reference() | nil
          }

    @enforce_keys [:codec, :codec_module, :encoding_deadline]
    defstruct @enforce_keys ++
                [
                  encoder_ref: nil
                ]
  end

  @type callback_return :: {[Membrane.Element.Action.t()], State.t()}

  @spec handle_init(CallbackContext.t(), VP8.Encoder.t() | VP9.Encoder.t(), :vp8 | :vp9) ::
          callback_return()
  def handle_init(_ctx, opts, codec) do
    state = %State{
      codec: codec,
      codec_module:
        case codec do
          :vp8 -> VP8
          :vp9 -> VP9
        end,
      encoding_deadline: opts.encoding_deadline
    }

    {[], state}
  end

  @spec handle_stream_format(:input, RawVideo.t(), CallbackContext.t(), State.t()) ::
          callback_return()
  def handle_stream_format(:input, stream_format, ctx, state) do
    %RawVideo{
      width: width,
      height: height,
      framerate: framerate
    } = stream_format

    output_stream_format =
      struct(state.codec_module, width: width, height: height, framerate: framerate)

    {flushed_buffers, encoder_ref} =
      maybe_recreate_encoder(ctx.pads.input.stream_format, stream_format, state)

    {
      [buffer: {:output, flushed_buffers}, stream_format: {:output, output_stream_format}],
      %{state | encoder_ref: encoder_ref}
    }
  end

  @spec handle_buffer(:input, Membrane.Buffer.t(), CallbackContext.t(), State.t()) ::
          callback_return()
  def handle_buffer(:input, %Buffer{payload: payload, pts: pts}, _ctx, state) do
    {:ok, encoded_frames, timestamps} = Native.encode_frame(payload, pts, state.encoder_ref)

    buffers =
      Enum.zip(encoded_frames, timestamps)
      |> Enum.map(fn {frame, frame_pts} -> %Buffer{payload: frame, pts: frame_pts} end)

    {[buffer: {:output, buffers}], state}
  end

  @spec handle_event(:output, DemandKeyframeEvent.t(), CallbackContext.t(), State.t()) ::
          callback_return()
  def handle_event(:output, %DemandKeyframeEvent{}, _ctx, state) do
  end

  @spec handle_end_of_stream(:input, CallbackContext.t(), State.t()) :: callback_return()
  def handle_end_of_stream(:input, _ctx, state) do
    buffers = flush(state.encoder_ref)
    {[buffer: {:output, buffers}, end_of_stream: :output], state}
  end

  @spec maybe_recreate_encoder(
          previous_stream_format :: RawVideo.t(),
          new_stream_format :: RawVideo.t(),
          State.t()
        ) :: {flushed_buffers :: [Buffer.t()], encoder_ref :: reference()}
  defp maybe_recreate_encoder(unchanged_stream_format, unchanged_stream_format, state) do
    {[], state.encoder_ref}
  end

  defp maybe_recreate_encoder(_previous_stream_format, new_stream_format, state) do
    %RawVideo{
      width: width,
      height: height,
      framerate: framerate,
      pixel_format: pixel_format
    } = new_stream_format

    encoding_deadline =
      case {state.encoding_deadline, framerate} do
        {:auto, nil} -> @default_encoding_deadline |> Membrane.Time.as_microseconds(:round)
        {:auto, {num, denom}} -> div(denom * 1_000_000, num)
        {fixed_deadline, _framerate} -> fixed_deadline |> Membrane.Time.as_microseconds(:round)
      end

    new_encoder_ref =
      Native.create!(state.codec, width, height, pixel_format, encoding_deadline)

    case state.encoder_ref do
      nil -> {[], new_encoder_ref}
      old_encoder_ref -> {flush(old_encoder_ref), new_encoder_ref}
    end
  end

  @spec flush(reference()) :: [Membrane.Buffer.t()]
  defp flush(encoder_ref) do
    {:ok, encoded_frames, timestamps} = Native.flush(encoder_ref)

    Enum.zip(encoded_frames, timestamps)
    |> Enum.map(fn {frame, frame_pts} -> %Buffer{payload: frame, pts: frame_pts} end)
  end
end
