#include "vpx_common.h"

Dimensions get_plane_dimensions(const vpx_image_t *img, int plane) {
  const int height = (plane > 0 && img->y_chroma_shift > 0)
                         ? (img->d_h + 1) >> img->y_chroma_shift
                         : img->d_h;

  int width = (plane > 0 && img->x_chroma_shift > 0)
                  ? (img->d_w + 1) >> img->x_chroma_shift
                  : img->d_w;

  // Fixing NV12 chroma width if it is odd
  if (img->fmt == VPX_IMG_FMT_NV12 && plane == 1)
    width = (width + 1) & ~1;

  return (Dimensions){width, height};
}

void free_payloads(UnifexEnv *env, UnifexPayload **payloads,
                   unsigned int payloads_cnt) {

  for (unsigned int i = 0; i < payloads_cnt; i++) {
    if (payloads[i] != NULL) {
      unifex_payload_release(payloads[i]);
      unifex_free(payloads[i]);
    }
  }
  unifex_free(payloads);
}
