defmodule Membrane.ForceKeyframeEvent do
  @moduledoc """
  Event that causes the next frame produced by the encoder to be a keyframe
  """
  @derive Membrane.EventProtocol

  @type t :: %__MODULE__{}
  defstruct []
end
