defmodule Membrane.VP8.Decoder do
  @moduledoc """
  Element that decodes a VP8 stream
  """
  use Membrane.Filter

  alias Membrane.Buffer
  alias Membrane.VP8
  alias __MODULE__.Native

  def_input_pad :input,
    accepted_format:
      any_of(
        Membrane.VP8,
        %Membrane.RemoteStream{content_format: format} when format in [nil, VP8]
      )

  def_output_pad :output,
    accepted_format: Membrane.RawVideo

  defmodule State do
    @moduledoc false
    @type t :: %__MODULE__{
            decoder_ref: reference() | nil
          }

    @enforce_keys []
    defstruct @enforce_keys ++
                [
                  decoder_ref: nil
                ]
  end

  @impl true
  def handle_init(_ctx, _opts) do
    {[], %State{}}
  end

  @impl true
  def handle_setup(_ctx, state) do
    native = Native.create!()

    {[], %{state | decoder_ref: native}}
  end

  @impl true
  def handle_playing(_ctx, state) do
    stream_format =
      %Membrane.RawVideo{
        width: 0,
        height: 0,
        framerate: {0, 0},
        pixel_format: :I420,
        aligned: true
      }

    {[stream_format: {:output, stream_format}], state}
  end

  @impl true
  def handle_stream_format(:input, _stream_format, _ctx, state) do
    {[], state}
  end

  @impl true
  def handle_buffer(:input, %Buffer{payload: payload}, _ctx, state) do
    {:ok, decoded_frames} = Native.decode_frame(payload, state.decoder_ref)
    buffers = Enum.map(decoded_frames, &%Buffer{payload: &1})
    {[buffer: {:output, buffers}], state}
  end
end
