#include "_generated/vp8_decoder.h"
#include "vpx/vp8dx.h"
#include "vpx/vpx_decoder.h"

typedef struct State {
  vpx_codec_ctx_t codec_context;
  vpx_codec_iface_t *codec_interface;
} State;