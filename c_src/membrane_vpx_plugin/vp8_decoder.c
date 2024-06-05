#include "vp8_decoder.h"

UNIFEX_TERM create(UnifexEnv *env) {
  UNIFEX_TERM result;
  State *state = unifex_alloc_state(env);
  vpx_codec_ctx_t codec_context;
  vpx_codec_iface_t *codec_interface;

  if (vpx_codec_dec_init(&codec_context, codec_interface, NULL, 0)) {
    result = create_result_error(env, "Failed to initialize decoder");
    unifex_release_state(env, state);
    return result;
  }
  result = create_result_ok(env, state);
  unifex_release_state(env, state);
  return result;
}