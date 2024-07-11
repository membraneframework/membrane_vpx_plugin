defmodule Membrane.VPx.Encoder do
  @moduledoc false

  alias Membrane.{Buffer, KeyframeRequestEvent, RawVideo, VP8, VP9}
  alias Membrane.Element.CallbackContext
  alias Membrane.VPx.Encoder.Native

  @default_encoding_deadline Membrane.Time.milliseconds(10)

  defmodule State do
    @moduledoc false

    @type t :: %__MODULE__{
            codec: :vp8 | :vp9,
            codec_module: VP8 | VP9,
            encoding_deadline: non_neg_integer(),
            target_bitrate: pos_integer(),
            encoder_ref: reference() | nil,
            force_next_keyframe: boolean()
          }

    @enforce_keys [:codec, :codec_module, :encoding_deadline, :target_bitrate]
    defstruct @enforce_keys ++
                [
                  encoder_ref: nil,
                  force_next_keyframe: false
                ]
  end

  @type callback_return :: {[Membrane.Element.Action.t()], State.t()}

  @type encoder_options :: %{
          width: pos_integer(),
          height: pos_integer(),
          pixel_format: Membrane.RawVideo.pixel_format(),
          encoding_deadline: non_neg_integer(),
          target_bitrate: pos_integer()
        }

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
      encoding_deadline: opts.encoding_deadline,
      target_bitrate: opts.target_bitrate
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

    force_next_keyframe = if flushed_buffers == [], do: state.force_next_keyframe, else: false

    {
      [buffer: {:output, flushed_buffers}, stream_format: {:output, output_stream_format}],
      %{state | encoder_ref: encoder_ref, force_next_keyframe: force_next_keyframe}
    }
  end

  @spec handle_buffer(:input, Membrane.Buffer.t(), CallbackContext.t(), State.t()) ::
          callback_return()
  def handle_buffer(:input, %Buffer{payload: payload, pts: pts}, _ctx, state) do
    {:ok, encoded_frames} =
      Native.encode_frame(payload, pts, state.force_next_keyframe, state.encoder_ref)

    buffers = get_buffers_from_frames(encoded_frames, state.codec)

    {[buffer: {:output, buffers}], %{state | force_next_keyframe: false}}
  end

  @spec handle_event(:output, KeyframeRequestEvent.t(), CallbackContext.t(), State.t()) ::
          callback_return()
  def handle_event(:output, %KeyframeRequestEvent{}, _ctx, state) do
    {[], %{state | force_next_keyframe: true}}
  end

  @spec handle_end_of_stream(:input, CallbackContext.t(), State.t()) :: callback_return()
  def handle_end_of_stream(:input, _ctx, state) do
    buffers = flush(state.force_next_keyframe, state.encoder_ref, state.codec)
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

    encoder_options = %{
      width: width,
      height: height,
      pixel_format: pixel_format,
      encoding_deadline: encoding_deadline,
      target_bitrate: state.target_bitrate
    }

    new_encoder_ref = Native.create!(state.codec, encoder_options)

    case state.encoder_ref do
      nil ->
        {[], new_encoder_ref}

      old_encoder_ref ->
        {flush(state.force_next_keyframe, old_encoder_ref, state.codec), new_encoder_ref}
    end
  end

  @spec flush(boolean(), reference(), :vp8 | :vp9) :: [Membrane.Buffer.t()]
  defp flush(force_next_keyframe, encoder_ref, codec) do
    {:ok, encoded_frames} = Native.flush(force_next_keyframe, encoder_ref)

    get_buffers_from_frames(encoded_frames, codec)
  end

  @spec get_buffers_from_frames([EncodedFrame.t()], :vp8 | :vp9) :: [Buffer.t()]
  def get_buffers_from_frames(encoded_frames, codec) do
    Enum.map(encoded_frames, fn %{payload: payload, pts: pts, is_keyframe: is_keyframe} ->
      %Buffer{
        payload: payload,
        pts: pts,
        metadata: %{codec => %{is_keyframe: is_keyframe}}
      }
    end)
  end
end
