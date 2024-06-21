#include "vpx_encoder.h"

void handle_destroy_state(UnifexEnv *env, State *state) {
  UNIFEX_UNUSED(env);

  vpx_codec_destroy(&state->codec_context);
}

vpx_img_fmt_t translate_pixel_format(PixelFormat pixel_format) {
  switch (pixel_format) {
  case PIXEL_FORMAT_I420:
    return VPX_IMG_FMT_I420;
  case PIXEL_FORMAT_I422:
    return VPX_IMG_FMT_I422;
  case PIXEL_FORMAT_I444:
    return VPX_IMG_FMT_I444;
  case PIXEL_FORMAT_YV12:
    return VPX_IMG_FMT_YV12;
  case PIXEL_FORMAT_NV12:
    return VPX_IMG_FMT_NV12;
  }
}

UNIFEX_TERM create(UnifexEnv *env, Codec codec, unsigned int width,
                   unsigned int height, PixelFormat pixel_format) {
  UNIFEX_TERM result;
  State *state = unifex_alloc_state(env);
  vpx_codec_enc_cfg_t config;

  switch (codec) {
  case CODEC_VP8:
    state->codec_interface = vpx_codec_vp8_cx();
    break;
  case CODEC_VP9:
    state->codec_interface = vpx_codec_vp9_cx();
    break;
  }

  if (vpx_codec_enc_config_default(state->codec_interface, &config, 0)) {
    result = create_result_error(env, "Failed to get default codec config");
    unifex_release_state(env, state);
    return result;
  }

  config.g_h = height;
  config.g_w = width;
  config.g_timebase.num = 1;
  config.g_timebase.den = 1000000000; // 1e9
  config.rc_target_bitrate = 200;
  config.g_error_resilient = 1;

  vpx_codec_err_t res = vpx_codec_enc_init(&state->codec_context,
                                           state->codec_interface, &config, 0);
  if (res) {
    printf("dupa: %d\n", res);
    result = create_result_error(env, "Failed to initialize encoder");
    unifex_release_state(env, state);
    return result;
  }
  if (!vpx_img_alloc(&state->img, translate_pixel_format(pixel_format), width,
                     height, 1)) {
    result = create_result_error(env, "Failed to allocate image");
    unifex_release_state(env, state);
    return result;
  }
  result = create_result_ok(env, state);
  unifex_release_state(env, state);
  return result;
}

UNIFEX_TERM encode_frame(UnifexEnv *env, UnifexPayload *raw_frame,
                         vpx_codec_pts_t pts, State *state) {}

UNIFEX_TERM flush(UnifexEnv *env, State *state) {}