defmodule Membrane.VPx.KeyframesTest do
  use ExUnit.Case, async: true

  import Membrane.Testing.Assertions
  import Membrane.ChildrenSpec

  defmodule KeyframeRequester do
    use Membrane.Filter
    alias Membrane.{KeyframeRequestEvent, VP8, VP9}

    def_input_pad :input,
      accepted_format: any_of(VP8, VP9)

    def_output_pad :output,
      accepted_format: any_of(VP8, VP9)

    @impl true
    def handle_init(_ctx, _opts) do
      {[], %{frames_since_last_keyframe: 0}}
    end

    @impl true
    def handle_buffer(:input, buffer, _ctx, state) do
      {maybe_event_action, frames_since_last_keyframe} =
        if state.frames_since_last_keyframe == 4 do
          {[event: {:input, %KeyframeRequestEvent{}}], 0}
        else
          {[], state.frames_since_last_keyframe + 1}
        end

      {
        maybe_event_action ++ [buffer: {:output, buffer}],
        %{state | frames_since_last_keyframe: frames_since_last_keyframe}
      }
    end
  end

  @fixtures_dir "test/fixtures"

  describe "Keyframes are forced correctly for" do
    @tag :sometag
    test "VP8 codec" do
      perform_test(
        "ref_vp8.raw",
        %Membrane.VP8.Encoder{encoding_deadline: 1, g_lag_in_frames: 0},
        :vp8
      )
    end

    test "VP9 codec" do
      perform_test(
        "ref_vp9.raw",
        %Membrane.VP9.Encoder{encoding_deadline: 1, g_lag_in_frames: 0},
        :vp9
      )
    end
  end

  defp perform_test(input_file, encoder_struct, metadata_key) do
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
            framerate: {5, 1}
          })
          |> child(:realtimer, Membrane.Realtimer)
          |> child(:encoder, encoder_struct)
          |> child(:keyframe_forcer, KeyframeRequester)
          |> child(:sink, Membrane.Testing.Sink)
      )

    assert_end_of_stream(pid, :sink, :input, 10_000)

    Enum.each(1..6, fn _n ->
      assert_sink_buffer(pid, :sink, %Membrane.Buffer{
        metadata: %{^metadata_key => %{is_keyframe: true}}
      })
    end)

    Membrane.Testing.Pipeline.terminate(pid)
  end
end
