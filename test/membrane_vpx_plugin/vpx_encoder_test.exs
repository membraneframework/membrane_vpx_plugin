defmodule Membrane.VPx.EncoderTest do
  use ExUnit.Case, async: true

  import Membrane.Testing.Assertions
  import Membrane.ChildrenSpec

  @fixtures_dir "test/fixtures"

  describe "Encoder encodes correctly for" do
    @describetag :tmp_dir
    test "VP8 codec", %{tmp_dir: tmp_dir} do
      perform_decoder_test(
        tmp_dir,
        "ref_vp8.raw",
        "output_vp8.ivf",
        "ref_vp8.ivf",
        %Membrane.VP8.Encoder{}
      )
    end

    test "VP9 codec", %{tmp_dir: tmp_dir} do
      perform_decoder_test(
        tmp_dir,
        "ref_vp9.ivf",
        "output_vp9.ivf",
        "ref_vp9.ivf",
        %Membrane.VP9.Encoder{}
      )
    end
  end

  defp perform_decoder_test(tmp_dir, input_file, output_file, ref_file, decoder_struct) do
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
          |> child(%Membrane.Debug.Filter{handle_buffer: &IO.inspect(&1.pts, label: "pts")})
          |> child(:decoder, decoder_struct)
          |> child(:serializer, %Membrane.IVF.Serializer{
            width: 1080,
            height: 720,
            rate: 1_000_000_000
          })
          |> child(:sink, %Membrane.File.Sink{location: output_path})
      )

    assert_end_of_stream(pid, :sink, :input, 2000)

    # assert File.read(ref_path) == File.read(output_path)
  end
end