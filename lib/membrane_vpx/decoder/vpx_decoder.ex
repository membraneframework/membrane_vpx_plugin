defmodule Membrane.VPx.Decoder do
  @moduledoc false

  alias Membrane.{Buffer, RawVideo, RemoteStream, VP8, VP9}
  alias Membrane.Element.CallbackContext
  alias Membrane.VPx.Decoder.Native

  defmodule State do
    @moduledoc false

    @type t :: %__MODULE__{
            codec: :vp8 | :vp9,
            width: pos_integer() | nil,
            height: pos_integer() | nil,
            framerate: {pos_integer(), pos_integer()} | nil,
            decoder_ref: reference() | nil
          }

    @enforce_keys [:codec, :width, :height, :framerate]
    defstruct @enforce_keys ++
                [
                  decoder_ref: nil
                ]
  end

  @type callback_return :: {[Membrane.Element.Action.t()], State.t()}

  @spec handle_init(CallbackContext.t(), VP8.Decoder.t() | VP9.Decoder.t(), :vp8 | :vp9) ::
          callback_return()
  def handle_init(_ctx, opts, codec) do
    state_fields =
      opts
      |> Map.take([:width, :height, :framerate])
      |> Map.put(:codec, codec)

    {[], struct(State, state_fields)}
  end

  @spec handle_setup(CallbackContext.t(), State.t()) :: callback_return()
  def handle_setup(_ctx, state) do
    native = Native.create!(state.codec)

    {[], %{state | decoder_ref: native}}
  end

  @spec handle_stream_format(:input, term(), CallbackContext.t(), State.t()) :: callback_return()
  def handle_stream_format(:input, _stream_format, _ctx, state) do
    {[], state}
  end

  @spec handle_buffer(:input, Membrane.Buffer.t(), CallbackContext.t(), State.t()) ::
          callback_return()
  def handle_buffer(:input, %Buffer{payload: payload, pts: pts}, ctx, state) do
    {:ok, [decoded_frame], pixel_format} = Native.decode_frame(payload, state.decoder_ref)

    stream_format_action =
      if ctx.pads.output.stream_format == nil do
        output_stream_format =
          get_output_stream_format(ctx.pads.input.stream_format, pixel_format, state)

        [stream_format: {:output, output_stream_format}]
      else
        []
      end

    {stream_format_action ++ [buffer: {:output, %Buffer{payload: decoded_frame, pts: pts}}],
     state}
  end

  @spec get_output_stream_format(
          RemoteStream.t() | VP8.t() | VP9.t(),
          RawVideo.pixel_format(),
          State.t()
        ) :: RawVideo.t()
  defp get_output_stream_format(input_stream_format, pixel_format, state) do
    {width, height, framerate} =
      case input_stream_format do
        %RemoteStream{} ->
          {
            state.width || raise("Width not provided"),
            state.height || raise("Height not provided"),
            state.framerate
          }

        %{width: width, height: height} ->
          {
            width,
            height,
            state.framerate
          }
      end

    %RawVideo{
      width: width,
      height: height,
      framerate: framerate,
      pixel_format: pixel_format,
      aligned: true
    }
  end
end
