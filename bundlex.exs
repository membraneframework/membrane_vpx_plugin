defmodule Membrane.VPx.BundlexProject do
  use Bundlex.Project

  def project() do
    [
      natives: natives()
    ]
  end

  defp natives() do
    [
      vpx_decoder: [
        interface: :nif,
        sources: ["vpx_decoder.c"],
        os_deps: [
          libvpx: [{:pkg_config, "vpx"}]
        ],
        preprocessor: Unifex
      ]
      # vpx_encoder: [
      #   interface: :nif,
      #   sources: ["vpx_encoder.c"],
      #   os_deps: [
      #     libvpx: [{:pkg_config, "vpx"}]
      #   ],
      #   preprocessor: Unifex
      # ]
    ]
  end
end
