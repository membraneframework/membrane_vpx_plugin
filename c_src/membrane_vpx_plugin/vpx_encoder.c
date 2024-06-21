#include "vpx_encoder.h"

void handle_destroy_state(UnifexEnv *env, State *state) {
  UNIFEX_UNUSED(env);

  vpx_codec_destroy(&state->codec_context);
}

UNIFEX_TERM error(UnifexEnv *env, const char *reason, State *state) {
  if (&state->codec_context) {
    const char *detail = vpx_codec_error_detail(&state->codec_context);
    fprintf(stderr, "%s: %s\n", reason, vpx_codec_error(&state->codec_context));
    if (detail) {
      fprintf(stderr, "    %s\n", detail);
    }
  }
  UNIFEX_TERM result = create_result_error(env, reason);
  unifex_release_state(env, state);
  return result;
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
    return error(env, "Failed to get default codec config", state);
  }

  config.g_h = height;
  config.g_w = width;
  config.g_timebase.num = 1;
  config.g_timebase.den = 1000000000; // 1e9
  config.rc_target_bitrate = 200;
  config.g_error_resilient = 1;

  if (vpx_codec_enc_init(&state->codec_context, state->codec_interface, &config,
                         0)) {
    return error(env, "Failed to initialize encoder", state);
  }
  if (!vpx_img_alloc(&state->img, translate_pixel_format(pixel_format), width,
                     height, 1)) {
    return error(env, "Failed to allocate image", state);
  }
  result = create_result_ok(env, state);
  unifex_release_state(env, state);
  return result;
}

void get_image_from_raw_frame(vpx_image_t *img, UnifexPayload *raw_frame) {
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
      memcpy(buf, frame_data, bytes_to_write);
      buf += stride;
      frame_data += bytes_to_write;
    }
  }
}

UNIFEX_TERM encode_frame(UnifexEnv *env, UnifexPayload *raw_frame,
                         vpx_codec_pts_t pts, State *state) {
  vpx_codec_iter_t iter = NULL;
  int got_pkts = 0;
  const vpx_codec_cx_pkt_t *packet = NULL;
  unsigned int frames_cnt = 0, max_frames = 2;
  UnifexPayload **encoded_frames =
      unifex_alloc(max_frames * sizeof(*encoded_frames));

  get_image_from_raw_frame(&state->img, raw_frame);
  if (vpx_codec_encode(&state->codec_context, &state->img, pts, 1, 0,
                       VPX_DL_GOOD_QUALITY) != VPX_CODEC_OK) {
    return error(env, "Failed to encode frame", state);
  }

  while ((packet = vpx_codec_get_cx_data(&state->codec_context, &iter)) !=
         NULL) {
    got_pkts = 1;
    if (frames_cnt >= max_frames) {
      max_frames *= 2;
      encoded_frames =
          unifex_realloc(encoded_frames, max_frames * sizeof(*encoded_frames));
    }

    if (packet->kind == VPX_CODEC_CX_FRAME_PKT) {
      //   const int keyframe = (pkt->data.frame.flags & VPX_FRAME_IS_KEY) != 0;
      unifex_payload_alloc(env, UNIFEX_PAYLOAD_BINARY, packet->data.frame.sz,
                           &encoded_frames[frames_cnt]);
      memcpy(encoded_frames[frames_cnt], packet->data.frame.buf,
             packet->data.frame.sz);
      frames_cnt++;
    }
  }

  UNIFEX_TERM result = encode_frame_result_ok(env, encoded_frames, frames_cnt);

  free_payloads(env, encoded_frames, frames_cnt);

  return result;
}

UNIFEX_TERM flush(UnifexEnv *env, State *state) {}