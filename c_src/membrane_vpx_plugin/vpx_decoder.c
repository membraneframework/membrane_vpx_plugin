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

  if (vpx_codec_dec_init(&state->codec_context, state->codec_interface, NULL, 0)) {
    result = create_result_error(env, "Failed to initialize decoder");
    unifex_release_state(env, state);
    return result;
  }
  result = create_result_ok(env, state);
  unifex_release_state(env, state);
  return result;
}

size_t get_image_byte_size(const vpx_image_t *img) {
  const int bytes_per_pixel = (img->fmt & VPX_IMG_FMT_HIGHBITDEPTH) ? 2 : 1;
  const int number_of_planes = (img->fmt == VPX_IMG_FMT_NV12) ? 2 : 3;

  size_t image_size = 0;

  for (int plane = 0; plane < number_of_planes; ++plane) {
    Dimensions plane_dimensions = get_plane_dimensions(img, plane);
    image_size += plane_dimensions.width * plane_dimensions.height * bytes_per_pixel;
  }
  return image_size;
}

void get_raw_frame_from_image(const vpx_image_t *img, UnifexPayload *raw_frame) {
  const int bytes_per_pixel = (img->fmt & VPX_IMG_FMT_HIGHBITDEPTH) ? 2 : 1;

  // Assuming that for nv12 we write all chroma data at once
  const int number_of_planes = (img->fmt == VPX_IMG_FMT_NV12) ? 2 : 3;
  unsigned char *frame_data = raw_frame->data;

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

void alloc_output_frame(UnifexEnv *env, const vpx_image_t *img, UnifexPayload **output_frame) {
  *output_frame = unifex_alloc(sizeof(UnifexPayload));
  unifex_payload_alloc(env, UNIFEX_PAYLOAD_BINARY, get_image_byte_size(img), *output_frame);
}

PixelFormat get_pixel_format_from_image(vpx_image_t *img) {
  switch (img->fmt) {
  case VPX_IMG_FMT_I422:
    return PIXEL_FORMAT_I422;

  case VPX_IMG_FMT_I420:
    return PIXEL_FORMAT_I420;

  case VPX_IMG_FMT_I444:
    return PIXEL_FORMAT_I444;

  case VPX_IMG_FMT_YV12:
    return PIXEL_FORMAT_YV12;

  case VPX_IMG_FMT_NV12:
    return PIXEL_FORMAT_NV12;

  default:
    return PIXEL_FORMAT_I420;
  }
}

UNIFEX_TERM decode_frame(UnifexEnv *env, UnifexPayload *frame, State *state) {
  vpx_codec_iter_t iter = NULL;
  vpx_image_t *img = NULL;
  PixelFormat pixel_format = PIXEL_FORMAT_I420;
  unsigned int frames_cnt = 0, allocated_frames = 2;
  UnifexPayload **output_frames = unifex_alloc(allocated_frames * sizeof(*output_frames));

  if (vpx_codec_decode(&state->codec_context, frame->data, frame->size, NULL, 0)) {
    return decode_frame_result_error(env, "Decoding frame failed");
  }

  while ((img = vpx_codec_get_frame(&state->codec_context, &iter)) != NULL) {
    if (frames_cnt >= allocated_frames) {
      allocated_frames *= 2;
      output_frames = unifex_realloc(output_frames, allocated_frames * sizeof(*output_frames));
    }

    alloc_output_frame(env, img, &output_frames[frames_cnt]);
    get_raw_frame_from_image(img, output_frames[frames_cnt]);
    pixel_format = get_pixel_format_from_image(img);
    frames_cnt++;
  }

  UNIFEX_TERM result = decode_frame_result_ok(env, output_frames, frames_cnt, pixel_format);

  free_payloads(output_frames, frames_cnt);

  return result;
}
