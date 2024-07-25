defmodule Membrane.VPx.EncoderTest do
  use ExUnit.Case, async: true

  import Membrane.Testing.Assertions
  import Membrane.ChildrenSpec

  @fixtures_dir "test/fixtures"

  describe "Encoder encodes correctly for" do
    @describetag :tmp_dir
    test "VP8 codec", %{tmp_dir: tmp_dir} do
      perform_encoder_test(
        tmp_dir,
        "ref_vp8.raw",
        "output_vp8.ivf",
        "ref_vp8.ivf",
        %Membrane.VP8.Encoder{encoding_deadline: 0, rc_target_bitrate: 256}
      )
    end

    test "VP9 codec", %{tmp_dir: tmp_dir} do
      perform_encoder_test(
        tmp_dir,
        "ref_vp9.raw",
        "output_vp9.ivf",
        "ref_vp9.ivf",
        %Membrane.VP9.Encoder{encoding_deadline: 0, rc_target_bitrate: 256}
      )
    end
  end

  defp perform_encoder_test(tmp_dir, input_file, output_file, ref_file, encoder_struct) do
    output_path = Path.join(tmp_dir, output_file)
    ref_path = Path.join(@fixtures_dir, ref_file)

    pid =
      Membrane.Testing.Pipeline.start_link_supervised!(
        spec:
          child(:source, %Membrane.File.Source{
            location: Path.join(@fixtures_dir, input_file)
          })
          |> child(:parser, %Membrane.RawVideo.Parser{
            pixel_format: :I420,
            width: 1080,
            height: 720,
            framerate: {30, 1}
          })
          |> child(:encoder, encoder_struct)
          |> child(:serializer, %Membrane.IVF.Serializer{
            timebase: {1, 30}
          })
          |> child(:sink, %Membrane.File.Sink{location: output_path})
      )

    assert_end_of_stream(pid, :sink, :input, 10_000)

    assert File.read!(ref_path) == File.read!(output_path)

    Membrane.Testing.Pipeline.terminate(pid)
  end
end
