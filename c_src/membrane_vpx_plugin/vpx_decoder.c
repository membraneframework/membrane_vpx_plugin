#include "vpx_decoder.h"

void handle_destroy_state(UnifexEnv *env, State *state) {
  UNIFEX_UNUSED(env);

  vpx_codec_destroy(&state->codec_context);
}

UNIFEX_TERM create(UnifexEnv *env, Codec codec) {
  UNIFEX_TERM result;
  State *state = unifex_alloc_state(env);

  switch (codec) {
  case CODEC_VP8:
    state->codec_interface = vpx_codec_vp8_dx();
    break;
  case CODEC_VP9:
    state->codec_interface = vpx_codec_vp9_dx();
    break;
  }

  if (vpx_codec_dec_init(&state->codec_context, state->codec_interface, NULL,
                         0)) {
    result = create_result_error(env, "Failed to initialize decoder");
    unifex_release_state(env, state);
    return result;
  }
  result = create_result_ok(env, state);
  unifex_release_state(env, state);
  return result;
}

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
size_t get_image_byte_size(const vpx_image_t *img) {
  const int bytes_per_pixel = (img->fmt & VPX_IMG_FMT_HIGHBITDEPTH) ? 2 : 1;
  const int number_of_planes = (img->fmt == VPX_IMG_FMT_NV12) ? 2 : 3;

  size_t image_size = 0;

  for (int plane = 0; plane < number_of_planes; ++plane) {
    Dimensions plane_dimensions = get_plane_dimensions(img, plane);
    image_size +=
        plane_dimensions.width * plane_dimensions.height * bytes_per_pixel;
  }
  return image_size;
}

void get_output_frame_from_image(const vpx_image_t *img,
                                 UnifexPayload *output_frame) {
  const int bytes_per_pixel = (img->fmt & VPX_IMG_FMT_HIGHBITDEPTH) ? 2 : 1;

  // Assuming that for nv12 we write all chroma data at once
  const int number_of_planes = (img->fmt == VPX_IMG_FMT_NV12) ? 2 : 3;
  unsigned char *frame_data = output_frame->data;

  for (int plane = 0; plane < number_of_planes; ++plane) {
    const unsigned char *buf = img->planes[plane];
    const int stride = img->stride[plane];
    Dimensions plane_dimensions = get_plane_dimensions(img, plane);

    for (unsigned int y = 0; y < plane_dimensions.height; ++y) {
      size_t bytes_to_write = bytes_per_pixel * plane_dimensions.width;
      memcpy(frame_data, buf, bytes_to_write);
      buf += stride;
      frame_data += bytes_to_write;
    }
  }
}

void alloc_output_frame(UnifexEnv *env, const vpx_image_t *img,
                        UnifexPayload **output_frame) {
  *output_frame = unifex_alloc(sizeof(UnifexPayload));
  unifex_payload_alloc(env, UNIFEX_PAYLOAD_BINARY, get_image_byte_size(img),
                       *output_frame);
}

UNIFEX_TERM decode_frame(UnifexEnv *env, UnifexPayload *frame, State *state) {
  vpx_codec_iter_t iter = NULL;
  vpx_image_t *img = NULL;
  unsigned int frames_cnt = 0, max_frames = 2;
  UnifexPayload **output_frames =
      unifex_alloc(max_frames * sizeof(*output_frames));

  if (vpx_codec_decode(&state->codec_context, frame->data, frame->size, NULL,
                       0)) {
    return decode_frame_result_error(env, "Decoding frame failed");
  }

  while ((img = vpx_codec_get_frame(&state->codec_context, &iter)) != NULL) {
    if (frames_cnt >= max_frames) {
      max_frames *= 2;
      output_frames =
          unifex_realloc(output_frames, max_frames * sizeof(*output_frames));
    }

    alloc_output_frame(env, img, &output_frames[frames_cnt]);
    get_output_frame_from_image(img, output_frames[frames_cnt]);
    frames_cnt++;
  }

  UNIFEX_TERM result = decode_frame_result_ok(env, output_frames, frames_cnt);
  for (unsigned int i = 0; i < frames_cnt; i++) {
    if (output_frames[i] != NULL) {
      unifex_payload_release(output_frames[i]);
      unifex_free(output_frames[i]);
    }
  }
  unifex_free(output_frames);

  return result;
}
