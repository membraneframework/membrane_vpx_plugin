defmodule Membrane.VPx.ZeroLatencyTest do
  use ExUnit.Case, async: true

  import Membrane.Testing.Assertions
  import Membrane.ChildrenSpec

  @fixtures_dir "test/fixtures"

  defmodule EOSSuppressor do
    use Membrane.Filter

    def_input_pad :input,
      accepted_format: _any

    def_output_pad :output,
      accepted_format: _any

    @impl true
    def handle_init(_ctx, _opts) do
      {[], %{processed_buffers: 0}}
    end

    @impl true
    def handle_buffer(:input, buffer, _ctx, state) do
      {[buffer: {:output, buffer}], %{state | processed_buffers: state.processed_buffers + 1}}
    end

    @impl true
    def handle_end_of_stream(:input, _ctx, state) do
      {[notify_parent: {:processed_buffers, state.processed_buffers}], state}
    end

    @impl true
    def handle_parent_notification(:send_eos, _ctx, state) do
      {[end_of_stream: :output], state}
    end
  end

  describe "Encoder doesn't buffer any frames for" do
    @describetag :tmp_dir
    test "VP8 codec" do
      perform_test(
        "ref_vp8.raw",
        %Membrane.VP8.Encoder{g_lag_in_frames: 0}
      )
    end

    test "VP9 codec" do
      perform_test(
        "ref_vp9.raw",
        %Membrane.VP9.Encoder{g_lag_in_frames: 0}
      )
    end
  end

  defp perform_test(input_file, encoder_struct) do
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
          |> child(:eos_suppressor, EOSSuppressor)
          |> child(:encoder, encoder_struct)
          |> child(:sink, Membrane.Testing.Sink)
      )

    assert_pipeline_notified(pid, :eos_suppressor, {:processed_buffers, processed_buffers})

    Enum.each(1..processed_buffers, fn _n -> assert_sink_buffer(pid, :sink, _buf) end)

    Membrane.Testing.Pipeline.notify_child(pid, :eos_suppressor, :send_eos)

    assert_end_of_stream(pid, :encoder)

    refute_sink_buffer(pid, :sink, _buf, 1000)

    Membrane.Testing.Pipeline.terminate(pid)
  end
end
