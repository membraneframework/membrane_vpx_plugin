module Membrane.VP8.Decoder.Native

state_type "State"

spec create() :: {:ok :: label, state} | {:error :: label, reason :: atom}

spec decode_frame(payload, state) ::
       {:ok :: label, frames :: [payload]} | {:error :: label, reason :: atom}
