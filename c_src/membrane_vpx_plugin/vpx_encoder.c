#include "vpx_encoder.h"

// The following code is based on the simple_encoder example provided by libvpx
// (https://github.com/webmproject/libvpx/blob/main/examples/simple_encoder.c)

void handle_destroy_state(UnifexEnv *env, State *state) {
  UNIFEX_UNUSED(env);

  vpx_codec_destroy(&state->codec_context);
}

UNIFEX_TERM error(UnifexEnv *env, const char *reason,
                  UNIFEX_TERM (*result_error_fun)(UnifexEnv *, const char *),
                  State *state) {
  if (&state->codec_context) {
    const char *detail = vpx_codec_error_detail(&state->codec_context);
    fprintf(stderr, "%s: %s\n", reason, vpx_codec_error(&state->codec_context));
    if (detail) {
      fprintf(stderr, "    %s\n", detail);
    }
  }
  UNIFEX_TERM result = result_error_fun(env, reason);
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

int translate_encoding_quality(EncodingQuality encoding_quality) {
  switch (encoding_quality) {
  case ENCODING_QUALITY_BEST:
    return 0;
  case ENCODING_QUALITY_GOOD:
    return 1000000;
  case ENCODING_QUALITY_REALTIME:
    return 1;
  }
}

UNIFEX_TERM create(UnifexEnv *env, Codec codec, unsigned int width,
                   unsigned int height, PixelFormat pixel_format,
                   EncodingQuality encoding_quality) {
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
  state->encoding_quality = translate_encoding_quality(encoding_quality);

  //   return error(env, "Failed to get default codec config", state);
  if (vpx_codec_enc_config_default(state->codec_interface, &config, 0)) {
    return error(env, "Failed to get default codec config", create_result_error,
                 state);
  }

  config.g_h = height;
  config.g_w = width;
  config.g_timebase.num = 1;
  config.g_timebase.den = 1000000000; // 1e9
  config.rc_target_bitrate = 200;
  config.g_error_resilient = 1;

  if (vpx_codec_enc_init(&state->codec_context, state->codec_interface, &config,
                         0)) {
    return error(env, "Failed to initialize encoder", create_result_error,
                 state);
  }
  if (!vpx_img_alloc(&state->img, translate_pixel_format(pixel_format), width,
                     height, 1)) {
    return error(env, "Failed to allocate image", create_result_error, state);
  }
  result = create_result_ok(env, state);
  unifex_release_state(env, state);
  return result;
}

void get_image_from_raw_frame(vpx_image_t *img, UnifexPayload *raw_frame) {
  convert_between_image_and_raw_frame(img, raw_frame, RAW_FRAME_TO_IMAGE);
}

void alloc_output_frame(UnifexEnv *env, const vpx_codec_cx_pkt_t *packet,
                        UnifexPayload **output_frame) {
  *output_frame = unifex_alloc(sizeof(UnifexPayload));
  unifex_payload_alloc(env, UNIFEX_PAYLOAD_BINARY, packet->data.frame.sz,
                       *output_frame);
}

UNIFEX_TERM encode(UnifexEnv *env, vpx_image_t *img, vpx_codec_pts_t pts,
                   State *state) {
  vpx_codec_iter_t iter = NULL;
  int flushing = (img == NULL), got_packets = 0;
  const vpx_codec_cx_pkt_t *packet = NULL;
  unsigned int frames_cnt = 0, max_frames = 2;
  UnifexPayload **encoded_frames =
      unifex_alloc(max_frames * sizeof(*encoded_frames));
  vpx_codec_pts_t *encoded_frames_timestamps =
      unifex_alloc(max_frames * sizeof(*encoded_frames_timestamps));

  do {
    if (vpx_codec_encode(&state->codec_context, img, pts, 1, 0,
                         state->encoding_quality) != VPX_CODEC_OK) {
      if (flushing) {
        return error(env, "Encoding frame failed", flush_result_error, state);
      } else {
        return error(env, "Encoding frame failed", encode_frame_result_error,
                     state);
      }
    }
    got_packets = 0;

    while ((packet = vpx_codec_get_cx_data(&state->codec_context, &iter)) !=
           NULL) {
      got_packets = 1;
      if (packet->kind != VPX_CODEC_CX_FRAME_PKT)
        continue;

      if (frames_cnt >= max_frames) {
        max_frames *= 2;
        encoded_frames = unifex_realloc(encoded_frames,
                                        max_frames * sizeof(*encoded_frames));

        encoded_frames_timestamps =
            unifex_realloc(encoded_frames_timestamps,
                           max_frames * sizeof(*encoded_frames_timestamps));
      }
      alloc_output_frame(env, packet, &encoded_frames[frames_cnt]);
      memcpy(encoded_frames[frames_cnt]->data, packet->data.frame.buf,
             packet->data.frame.sz);
      encoded_frames_timestamps[frames_cnt] = packet->data.frame.pts;
      frames_cnt++;
    }
  } while (got_packets && flushing);

  UNIFEX_TERM result;
  if (flushing) {
    result = flush_result_ok(env, encoded_frames, frames_cnt,
                             encoded_frames_timestamps, frames_cnt);
  } else {
    result = encode_frame_result_ok(env, encoded_frames, frames_cnt,
                                    encoded_frames_timestamps, frames_cnt);
  }
  free_payloads(encoded_frames, frames_cnt);

  return result;
}

UNIFEX_TERM encode_frame(UnifexEnv *env, UnifexPayload *raw_frame,
                         vpx_codec_pts_t pts, State *state) {
  get_image_from_raw_frame(&state->img, raw_frame);
  return encode(env, &state->img, pts, state);
}

UNIFEX_TERM flush(UnifexEnv *env, State *state) {
  return encode(env, NULL, 0, state);
}