defmodule Membrane.VPx.BundlexProject do
  use Bundlex.Project

  def project() do
    [
      natives: natives()
    ]
  end

  defp natives() do
    [
      vp8_decoder: [
        interface: :nif,
        sources: ["vp8_decoder.c"],
        os_deps: [
          libvpx: [{:pkg_config, "vpx"}]
        ],
        preprocessor: Unifex
      ]
      # vp8_encoder: [
      #   interface: :nif,
      #   sources: ["encoder.c"],
      #   os_deps: [
      #     libvpx: [{:pkg_config, "vpx"}]
      #   ],
      #   preprocessor: Unifex
      # ]
    ]
  end
end
