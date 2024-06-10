defmodule Membrane.VP9.DecoderTest do
  use ExUnit.Case, async: true

  import Membrane.Testing.Assertions
  import Membrane.ChildrenSpec

  @fixtures_dir "test/fixtures"

  @tag :tmp_dir
  test "Decoder decodes", %{tmp_dir: tmp_dir} do
    pid =
      Membrane.Testing.Pipeline.start_link_supervised!(
        spec:
          child(:source, %Membrane.File.Source{
            location: Path.join(@fixtures_dir, "input_vp9.ivf")
          })
          |> child(:deserializer, Membrane.Element.IVF.Deserializer)
          |> child(:decoder, Membrane.VP8.Decoder)
          |> child(:sink, %Membrane.File.Sink{location: Path.join(tmp_dir, "output.vp9")})
      )

    assert_end_of_stream(pid, :sink, :input, 2000)
  end
end
