module Membrane.VPx.Encoder.Native

state_type "State"

type codec :: :vp8 | :vp9

type pixel_format :: :I420 | :I422 | :I444 | :NV12 | :YV12

type encoded_frame :: %EncodedFrame{
  payload: payload,
  pts: int64,
  is_keyframe: bool
}

spec create(
       codec,
       width :: unsigned,
       height :: unsigned,
       pixel_format,
       encoding_deadline :: unsigned
     ) ::
       {:ok :: label, state} | {:error :: label, reason :: atom}

spec encode_frame(payload, pts :: int64, force_keyframe :: bool, state) ::
       {:ok :: label, frames :: [encoded_frame]}
       | {:error :: label, reason :: atom}

spec flush(force_keyframe :: bool, state) ::
       {:ok :: label, frames :: [encoded_frame]}
       | {:error :: label, reason :: atom}

dirty :cpu, [:create, :encode_frame, :flush]
