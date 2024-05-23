defmodule Membrane.VPx.BundlexProject do
  use Bundlex.Project

  def project() do
    [
      natives: natives()
    ]
  end

  defp natives() do
    [
      decoder: [
        interface: :nif,
        sources: ["decoder.c"],
        os_deps: [
          libvpx: [{:pkg_config, "vpx"}]
        ],
        preprocessor: Unifex
      ],
      encoder: [
        interface: :nif,
        sources: ["encoder.c"],
        os_deps: [
          libvpx: [{:pkg_config, "vpx"}]
        ],
        preprocessor: Unifex
      ]
    ]
  end
end
