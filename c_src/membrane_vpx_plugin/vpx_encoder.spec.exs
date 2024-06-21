module Membrane.VPx.Encoder.Native

state_type "State"

type codec :: :vp8 | :vp9

type pixel_format :: :I420 | :I422 | :I444 | :NV12 | :YV12

spec create(
       codec,
       width :: unsigned,
       height :: unsigned,
       pixel_format,
       encoding_deadline :: unsigned
     ) ::
       {:ok :: label, state} | {:error :: label, reason :: atom}

spec encode_frame(payload, pts :: int64, state) ::
       {:ok :: label, frames :: [payload], timestamps :: [int64]}
       | {:error :: label, reason :: atom}

spec flush(state) ::
       {:ok :: label, frames :: [payload], timestamps :: [int64]}
       | {:error :: label, reason :: atom}

dirty :cpu, create: 5, encode_frame: 3, flush: 1
