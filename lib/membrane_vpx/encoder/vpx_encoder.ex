defmodule Membrane.VPx.Encoder do
  @moduledoc false

  alias Membrane.{Buffer, RawVideo, VP8, VP9}
  alias Membrane.Element.CallbackContext
  alias Membrane.VPx.Encoder.Native

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

  @spec handle_init(CallbackContext.t(), VP8.Decoder.t() | VP9.Decoder.t(), :vp8 | :vp9) ::
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
  def handle_stream_format(
        :input,
        raw_video_format,
        _ctx,
        %State{codec_module: codec_module} = state
      ) do
    %RawVideo{
      width: width,
      height: height,
      framerate: framerate,
      pixel_format: pixel_format
    } = raw_video_format

    output_stream_format =
      struct(codec_module, width: width, height: height, framerate: framerate)

    native = Native.create!(state.codec, width, height, pixel_format, state.encoding_deadline)

    {[stream_format: {:output, output_stream_format}], %{state | encoder_ref: native}}
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

  @spec handle_end_of_stream(:input, CallbackContext.t(), State.t()) :: callback_return()
  def handle_end_of_stream(:input, _ctx, state) do
    {:ok, encoded_frames, timestamps} = Native.flush(state.encoder_ref)

    buffers =
      Enum.zip(encoded_frames, timestamps)
      |> Enum.map(fn {frame, frame_pts} -> %Buffer{payload: frame, pts: frame_pts} end)

    {[buffer: {:output, buffers}, end_of_stream: :output], state}
  end
end
