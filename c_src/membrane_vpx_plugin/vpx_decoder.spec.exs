module Membrane.VPx.Decoder.Native

state_type "State"

type codec :: :vp8 | :vp9

type pixel_format :: :I420 | :I422 | :I444 | :NV12 | :YV12

spec create(codec) :: {:ok :: label, state} | {:error :: label, reason :: atom}

spec decode_frame(payload, state) ::
       {:ok :: label, frames :: [payload], pixel_format :: pixel_format}
       | {:error :: label, reason :: atom}

dirty :cpu, decode_frame: 2
