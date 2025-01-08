defmodule Membrane.VPx.Decoder do
  @moduledoc false

  require Membrane.Logger
  alias Membrane.{Buffer, RawVideo, RemoteStream, VP8, VP9}
  alias Membrane.Element.CallbackContext
  alias Membrane.VPx.Decoder.Native

  defmodule State do
    @moduledoc false

    @type t :: %__MODULE__{
            codec: :vp8 | :vp9,
            framerate: {pos_integer(), pos_integer()} | nil,
            decoder_ref: reference() | nil
          }

    @enforce_keys [:codec, :framerate]
    defstruct @enforce_keys ++
                [
                  decoder_ref: nil
                ]
  end

  @type callback_return :: {[Membrane.Element.Action.t()], State.t()}

  @spec handle_init(CallbackContext.t(), VP8.Decoder.t() | VP9.Decoder.t(), :vp8 | :vp9) ::
          callback_return()
  def handle_init(_ctx, opts, codec) do
    {[], %State{framerate: opts.framerate, codec: codec}}
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
    {:ok, [decoded_frame]} = Native.decode_frame(payload, state.decoder_ref)

    new_stream_format = %RawVideo{
      width: decoded_frame.width,
      height: decoded_frame.height,
      framerate: state.framerate,
      pixel_format: decoded_frame.pixel_format,
      aligned: true
    }

    stream_format_action =
      if new_stream_format != ctx.pads.output.stream_format do
        validate_stream_formats(ctx.pads.input.stream_format, new_stream_format)

        [stream_format: {:output, new_stream_format}]
      else
        []
      end

    {stream_format_action ++
       [buffer: {:output, %Buffer{payload: decoded_frame.payload, pts: pts}}], state}
  end

  @spec validate_stream_formats(RemoteStream.t() | VP8.t() | VP9.t(), RawVideo.t()) ::
          :ok
  defp validate_stream_formats(input_stream_format, output_stream_format) do
    case input_stream_format do
      %RemoteStream{} ->
        :ok

      %{width: width, height: height} ->
        if width != output_stream_format.width do
          Membrane.Logger.warning(
            "Image width specified in stream format: #{inspect(width)} differs from the real image width: #{inspect(output_stream_format.width)}, using the actual value."
          )
        end

        if height != output_stream_format.height do
          Membrane.Logger.warning(
            "Image height specified in stream format: #{inspect(height)} differs from the real image height: #{inspect(output_stream_format.height)}, using the actual value."
          )
        end

        :ok
    end
  end
end
