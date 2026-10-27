defmodule Membrane.VPx.Encoder.NativeTest do
  use ExUnit.Case, async: true

  alias Membrane.VPx.Encoder.Native

  @config %{g_lag_in_frames: 0, rc_target_bitrate: 256, g_threads: -1}

  test "encode_frame rejects frames shorter than the configured resolution" do
    assert {:ok, ref} = Native.create(:vp8, 320, 240, :I420, 1, 0, @config)

    for frame <- [<<>>, :binary.copy(<<0>>, 115_199)] do
      assert {:error, :invalid_frame_size} = Native.encode_frame(frame, 0, false, ref)
    end

    assert {:ok, _frames} = Native.encode_frame(:binary.copy(<<0>>, 115_200), 0, false, ref)
  end
end
