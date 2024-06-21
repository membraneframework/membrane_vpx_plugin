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
        sources: ["vpx_decoder.c", "vpx_common.c"],
        os_deps: [
          libvpx: [
            {:precompiled, Membrane.PrecompiledDependencyProvider.get_dependency_url(:libvpx)},
            {:pkg_config, "vpx"}
          ]
        ],
        preprocessor: Unifex
      ],
      vpx_encoder: [
        interface: :nif,
        sources: ["vpx_encoder.c", "vpx_common.c"],
        os_deps: [
          libvpx: [
            {:precompiled, Membrane.PrecompiledDependencyProvider.get_dependency_url(:libvpx)},
            {:pkg_config, "vpx"}
          ]
        ],
        preprocessor: Unifex
      ]
    ]
  end
end
