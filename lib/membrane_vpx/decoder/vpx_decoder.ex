defmodule Membrane.VPx.Decoder do
  alias Membrane.{Buffer, VP8, VP9}
  alias Membrane.Element.CallbackContext
  alias Membrane.VPx.Decoder.Native

  defmodule State do
    @moduledoc false
    @type t :: %__MODULE__{
            codec: :vp8 | :vp9,
            decoder_ref: reference() | nil
          }

    @enforce_keys [:codec]
    defstruct @enforce_keys ++
                [
                  decoder_ref: nil
                ]
  end

  @type callback_return :: {[Membrane.Element.Action.t()], State.t()}

  @spec handle_init(CallbackContext.t(), VP8.Decoder.t() | VP9.Decoder.t(), :vp8 | :vp9) ::
          callback_return()
  def handle_init(_ctx, _opts, codec) do
    {[], %State{codec: codec}}
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
    {:ok, decoded_frames, pixel_format} = Native.decode_frame(payload, state.decoder_ref)

    stream_format_action =
      if ctx.pads.output.stream_format == nil do
        input_stream_format = ctx.pads.input.stream_format

        output_stream_format = %Membrane.RawVideo{
          width: input_stream_format.width,
          height: input_stream_format.height,
          framerate: input_stream_format.framerate || {30, 1},
          pixel_format: pixel_format,
          aligned: true
        }

        [stream_format: {:output, output_stream_format}]
      else
        []
      end

    buffers = Enum.map(decoded_frames, &%Buffer{payload: &1, pts: pts})
    {stream_format_action ++ [buffer: {:output, buffers}], state}
  end
end
