#include "vpx_common.h"

UNIFEX_TERM result_error(
    UnifexEnv *env,
    const char *reason,
    UNIFEX_TERM (*result_error_fun)(UnifexEnv *, const char *),
    vpx_codec_ctx_t *codec_context,
    void *state
) {
  char *full_reason;
  if (codec_context) {
    const char *error = vpx_codec_error(codec_context);
    const char *detail = vpx_codec_error_detail(codec_context);
    if (detail) {
      full_reason = unifex_alloc(strlen(reason) + strlen(error) + strlen(detail) + 5);
      sprintf(full_reason, "%s: %s: %s", reason, error, detail);
    } else {
      full_reason = unifex_alloc(strlen(reason) + strlen(error) + 3);
      sprintf(full_reason, "%s: %s", reason, error);
    }
  } else {
    full_reason = unifex_alloc(strlen(reason) + 1);
    sprintf(full_reason, "%s", reason);
  }

  if (state) unifex_release_resource(state);

  UNIFEX_TERM result = result_error_fun(env, full_reason);
  unifex_free(full_reason);
  return result;
}

Dimensions get_plane_dimensions(const vpx_image_t *img, int plane) {
  const int height =
      (plane > 0 && img->y_chroma_shift > 0) ? (img->d_h + 1) >> img->y_chroma_shift : img->d_h;

  int width =
      (plane > 0 && img->x_chroma_shift > 0) ? (img->d_w + 1) >> img->x_chroma_shift : img->d_w;

  // Fixing NV12 chroma width if it is odd
  if (img->fmt == VPX_IMG_FMT_NV12 && plane == 1) width = (width + 1) & ~1;

  return (Dimensions){width, height};
}

void convert_between_image_and_raw_frame(
    vpx_image_t *img, UnifexPayload *raw_frame, ConversionType conversion_type
) {
  const int bytes_per_pixel = (img->fmt & VPX_IMG_FMT_HIGHBITDEPTH) ? 2 : 1;

  // Assuming that for nv12 we write all chroma data at once
  const int number_of_planes = (img->fmt == VPX_IMG_FMT_NV12) ? 2 : 3;
  unsigned char *frame_data = raw_frame->data;

  for (int plane = 0; plane < number_of_planes; ++plane) {
    unsigned char *image_buf = img->planes[plane];
    const int stride = img->stride[plane];
    Dimensions plane_dimensions = get_plane_dimensions(img, plane);

    for (unsigned int y = 0; y < plane_dimensions.height; ++y) {
      size_t bytes_to_write = bytes_per_pixel * plane_dimensions.width;
      switch (conversion_type) {
      case RAW_FRAME_TO_IMAGE:
        memcpy(image_buf, frame_data, bytes_to_write);
        break;

      case IMAGE_TO_RAW_FRAME:
        memcpy(frame_data, image_buf, bytes_to_write);
        break;
      }
      image_buf += stride;
      frame_data += bytes_to_write;
    }
  }
}
