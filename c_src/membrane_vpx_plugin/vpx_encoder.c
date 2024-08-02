#include "vpx_encoder.h"
#include "membrane_vpx_plugin/_generated/nif/vpx_encoder.h"
#include "unifex/payload.h"
#include <stdio.h>

// The following code is based on the simple_encoder example provided by libvpx
// (https://github.com/webmproject/libvpx/blob/main/examples/simple_encoder.c)

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
  default:
    return VPX_IMG_FMT_I420;
  }
}

UNIFEX_TERM create(UnifexEnv *env, Codec codec, encoder_options opts) {
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
  state->encoding_deadline = opts.encoding_deadline;

  if (vpx_codec_enc_config_default(state->codec_interface, &config, 0)) {
    return result_error(
        env, "Failed to get default codec config", create_result_error, NULL, state
    );
  }

  config.g_h = opts.height;
  config.g_w = opts.width;
  config.rc_target_bitrate = opts.rc_target_bitrate;
  config.g_timebase.num = 1;
  config.g_timebase.den = 1000000000; // 1e9
  config.g_error_resilient = 1;

  if (vpx_codec_enc_init(&state->codec_context, state->codec_interface, &config, 0)) {
    return result_error(env, "Failed to initialize encoder", create_result_error, NULL, state);
  }
  if (!vpx_img_alloc(
          &state->img, translate_pixel_format(opts.pixel_format), opts.width, opts.height, 1
      )) {
    return result_error(
        env, "Failed to allocate image", create_result_error, &state->codec_context, state
    );
  }
  result = create_result_ok(env, state);
  unifex_release_state(env, state);
  return result;
}

void get_image_from_raw_frame(vpx_image_t *img, UnifexPayload *raw_frame) {
  convert_between_image_and_raw_frame(img, raw_frame, RAW_FRAME_TO_IMAGE);
}

void alloc_output_frame(
    UnifexEnv *env, const vpx_codec_cx_pkt_t *packet, encoded_frame *output_frame
) {
  output_frame->payload = unifex_alloc(sizeof(UnifexPayload));
  unifex_payload_alloc(env, UNIFEX_PAYLOAD_BINARY, packet->data.frame.sz, output_frame->payload);
}

void free_frames(encoded_frame *frames, unsigned int frames_cnt) {
  for (unsigned int i = 0; i < frames_cnt; i++) {
    UnifexPayload *payload = frames[i].payload;
    if (payload != NULL) {
      unifex_payload_release(payload);
      unifex_free(payload);
    }
  }
  unifex_free(frames);
}

UNIFEX_TERM encode(
    UnifexEnv *env, vpx_image_t *img, vpx_codec_pts_t pts, int force_keyframe, State *state
) {
  vpx_codec_iter_t iter = NULL;
  int flushing = (img == NULL), got_packets = 0;
  const vpx_codec_cx_pkt_t *packet = NULL;

  unsigned int frames_cnt = 0, allocated_frames = 1;
  encoded_frame *encoded_frames = unifex_alloc(allocated_frames * sizeof(encoded_frame));

  do {
    // Reasoning for the do-while and while loops comes from the description of
    // vpx_codec_encode:
    //
    // When the last frame has been passed to the encoder, this function should
    // continue to be called, with the img parameter set to NULL. This will
    // signal the end-of-stream condition to the encoder and allow it to encode
    // any held buffers. Encoding is complete when vpx_codec_encode() is called
    // and vpx_codec_get_cx_data() returns no data.
    vpx_enc_frame_flags_t flags = force_keyframe ? VPX_EFLAG_FORCE_KF : 0;
    if (vpx_codec_encode(&state->codec_context, img, pts, 1, flags, state->encoding_deadline) !=
        VPX_CODEC_OK) {
      if (flushing) {
        return result_error(
            env, "Encoding frame failed", flush_result_error, &state->codec_context, NULL
        );
      } else {
        return result_error(
            env, "Encoding frame failed", encode_frame_result_error, &state->codec_context, NULL
        );
      }
    }
    force_keyframe = 0;
    got_packets = 0;

    while ((packet = vpx_codec_get_cx_data(&state->codec_context, &iter)) != NULL) {
      got_packets = 1;
      if (packet->kind != VPX_CODEC_CX_FRAME_PKT) continue;

      if (frames_cnt >= allocated_frames) {
        allocated_frames *= 2;
        encoded_frames = unifex_realloc(encoded_frames, allocated_frames * sizeof(encoded_frame));
      }
      alloc_output_frame(env, packet, &encoded_frames[frames_cnt]);
      memcpy(
          encoded_frames[frames_cnt].payload->data, packet->data.frame.buf, packet->data.frame.sz
      );
      encoded_frames[frames_cnt].pts = packet->data.frame.pts;
      encoded_frames[frames_cnt].is_keyframe = ((packet->data.frame.flags & VPX_FRAME_IS_KEY) != 0);
      frames_cnt++;
    }
  } while (got_packets && flushing);

  UNIFEX_TERM result;
  if (flushing) {
    result = flush_result_ok(env, encoded_frames, frames_cnt);
  } else {
    result = encode_frame_result_ok(env, encoded_frames, frames_cnt);
  }
  free_frames(encoded_frames, frames_cnt);

  return result;
}

UNIFEX_TERM encode_frame(
    UnifexEnv *env, UnifexPayload *raw_frame, vpx_codec_pts_t pts, int force_keyframe, State *state
) {
  get_image_from_raw_frame(&state->img, raw_frame);
  return encode(env, &state->img, pts, force_keyframe, state);
}

UNIFEX_TERM flush(UnifexEnv *env, State *state) { return encode(env, NULL, 0, 0, state); }
