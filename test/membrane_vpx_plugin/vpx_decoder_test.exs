defmodule Membrane.VPx.DecoderTest do
  use ExUnit.Case, async: true

  import Membrane.Testing.Assertions
  import Membrane.ChildrenSpec

  @fixtures_dir "test/fixtures"

  describe "Decoder decodes correctly for" do
    @describetag :tmp_dir
    test "VP8 codec", %{tmp_dir: tmp_dir} do
      perform_decoder_test(
        tmp_dir,
        "input_vp8.ivf",
        "output_vp8.raw",
        "ref_vp8.raw",
        %Membrane.VP8.Decoder{framerate: {30, 1}}
      )
    end

    test "VP9 codec", %{tmp_dir: tmp_dir} do
      perform_decoder_test(
        tmp_dir,
        "input_vp9.ivf",
        "output_vp9.raw",
        "ref_vp9.raw",
        %Membrane.VP9.Decoder{framerate: {30, 1}}
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
          |> child(:deserializer, Membrane.IVF.Deserializer)
          |> child(:decoder, decoder_struct)
          |> child(:sink, %Membrane.File.Sink{location: output_path})
      )

    assert_end_of_stream(pid, :sink, :input, 2000)

    assert File.read(ref_path) == File.read(output_path)
  end
end
