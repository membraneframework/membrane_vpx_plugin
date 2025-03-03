#include "vpx_decoder.h"

// The following code is based on the simple_decoder example provided by libvpx
// (https://github.com/webmproject/libvpx/blob/main/examples/simple_decoder.c)

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
    return result_error(env, "Failed to initialize decoder", create_result_error, NULL, state);
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

void get_raw_frame_from_image(vpx_image_t *img, UnifexPayload *raw_frame) {
  convert_between_image_and_raw_frame(img, raw_frame, IMAGE_TO_RAW_FRAME);
}

void alloc_output_frame(UnifexEnv *env, const vpx_image_t *img, decoded_frame *output_frame) {
  output_frame->payload = unifex_alloc(sizeof(UnifexPayload));
  unifex_payload_alloc(env, UNIFEX_PAYLOAD_BINARY, get_image_byte_size(img), output_frame->payload);
}

void free_frames(decoded_frame *output_frames, unsigned int payloads_cnt) {
  for (unsigned int i = 0; i < payloads_cnt; i++) {
    if (output_frames[i].payload != NULL) {
      unifex_payload_release(output_frames[i].payload);
      unifex_free(output_frames[i].payload);
    }
  }
  unifex_free(output_frames);
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
  unsigned int frames_cnt = 0, allocated_frames = 1;
  decoded_frame *output_frames = unifex_alloc(allocated_frames * sizeof(decoded_frame));

  if (vpx_codec_decode(&state->codec_context, frame->data, frame->size, NULL, 0)) {
    return result_error(
        env, "Decoding frame failed", decode_frame_result_error, &state->codec_context, NULL
    );
  }

  while ((img = vpx_codec_get_frame(&state->codec_context, &iter)) != NULL) {
    if (frames_cnt >= allocated_frames) {
      allocated_frames *= 2;
      output_frames = unifex_realloc(output_frames, allocated_frames * sizeof(decoded_frame));
    }

    alloc_output_frame(env, img, &output_frames[frames_cnt]);

    get_raw_frame_from_image(img, output_frames[frames_cnt].payload);
    output_frames[frames_cnt].pixel_format = get_pixel_format_from_image(img);
    output_frames[frames_cnt].width = img->d_w;
    output_frames[frames_cnt].height = img->d_h;
    frames_cnt++;
  }

  UNIFEX_TERM result = decode_frame_result_ok(env, output_frames, frames_cnt);

  free_frames(output_frames, frames_cnt);

  return result;
}
