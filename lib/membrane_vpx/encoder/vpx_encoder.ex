defmodule Membrane.VPx.Encoder do
  @moduledoc false

  alias Membrane.{Buffer, KeyframeRequestEvent, RawVideo, VP8, VP9}
  alias Membrane.Element.CallbackContext
  alias Membrane.VPx.Encoder.Native

  @default_encoding_deadline Membrane.Time.milliseconds(10)
  @bitrate_calculation_coefficient 0.14

  @type unprocessed_user_encoder_config :: %{
          g_lag_in_frames: non_neg_integer(),
          rc_target_bitrate: pos_integer() | :auto
        }
  @type user_encoder_config :: %{
          g_lag_in_frames: non_neg_integer(),
          rc_target_bitrate: pos_integer()
        }

  defmodule State do
    @moduledoc false

    @type t :: %__MODULE__{
            codec: :vp8 | :vp9,
            codec_module: VP8 | VP9,
            encoding_deadline: non_neg_integer() | :auto,
            user_encoder_config: Membrane.VPx.Encoder.unprocessed_user_encoder_config(),
            encoder_ref: reference() | nil,
            force_next_keyframe: boolean()
          }

    @enforce_keys [:codec, :codec_module, :encoding_deadline, :user_encoder_config]
    defstruct @enforce_keys ++
                [
                  encoder_ref: nil,
                  force_next_keyframe: false
                ]
  end

  @type callback_return :: {[Membrane.Element.Action.t()], State.t()}

  @type encoded_frame :: %{payload: binary(), pts: non_neg_integer(), is_keyframe: boolean()}

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
      user_encoder_config: %{
        g_lag_in_frames: opts.g_lag_in_frames,
        rc_target_bitrate: opts.rc_target_bitrate
      }
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
    buffers = flush(state.encoder_ref, state.codec)
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

    user_encoder_config =
      process_user_encoder_config(state.user_encoder_config, width, height, framerate)

    new_encoder_ref =
      Native.create!(
        state.codec,
        width,
        height,
        pixel_format,
        encoding_deadline,
        user_encoder_config
      )

    case state.encoder_ref do
      nil ->
        {[], new_encoder_ref}

      old_encoder_ref ->
        {flush(old_encoder_ref, state.codec), new_encoder_ref}
    end
  end

  @spec process_user_encoder_config(
          unprocessed_user_encoder_config(),
          pos_integer(),
          pos_integer(),
          {non_neg_integer(), pos_integer()} | nil
        ) :: user_encoder_config()
  defp process_user_encoder_config(user_encoder_config, width, height, framerate) do
    rc_target_bitrate =
      process_rc_target_bitrate(user_encoder_config.rc_target_bitrate, width, height, framerate)

    %{
      g_lag_in_frames: user_encoder_config.g_lag_in_frames,
      rc_target_bitrate: rc_target_bitrate
    }
  end

  @spec process_rc_target_bitrate(
          pos_integer() | :auto,
          pos_integer(),
          pos_integer(),
          {non_neg_integer(), pos_integer()} | nil
        ) :: pos_integer()
  defp process_rc_target_bitrate(:auto, width, height, framerate) do
    assumed_fps =
      case framerate do
        nil -> 30.0
        {framerate_num, framerate_denom} -> framerate_num / framerate_denom
      end

    (@bitrate_calculation_coefficient * width * height * assumed_fps) |> trunc() |> div(1000)
  end

  defp process_rc_target_bitrate(provided_bitrate, _width, _height, _framerate) do
    provided_bitrate
  end

  @spec flush(reference(), :vp8 | :vp9) :: [Membrane.Buffer.t()]
  defp flush(encoder_ref, codec) do
    {:ok, encoded_frames} = Native.flush(encoder_ref)

    get_buffers_from_frames(encoded_frames, codec)
  end

  @spec get_buffers_from_frames([encoded_frame()], :vp8 | :vp9) :: [Buffer.t()]
  defp get_buffers_from_frames(encoded_frames, codec) do
    Enum.map(encoded_frames, fn %{payload: payload, pts: pts, is_keyframe: is_keyframe} ->
      %Buffer{
        payload: payload,
        pts: Membrane.Time.nanoseconds(pts),
        metadata: %{codec => %{is_keyframe: is_keyframe}}
      }
    end)
  end
end
