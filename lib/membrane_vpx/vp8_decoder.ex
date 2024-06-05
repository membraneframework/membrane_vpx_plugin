defmodule Membrane.VP8.Decoder do
  @moduledoc """
  Element that decodes a VP8 stream
  """
  use Membrane.Filter

  def_input_pad :input,
    accepted_format: Membrane.VP8

  def_output_pad :output,
    accepted_format: Membrane.RawVideo

  defmodule State do
    @moduledoc false
    @type t :: %__MODULE__{
            native: term()
          }

    @enforce_keys []
    defstruct @enforce_keys ++
                [
                  native: nil
                ]
  end

  @impl true
  def handle_init(_ctx, _opts) do
    {[], %State{}}
  end
end
