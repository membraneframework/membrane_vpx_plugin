#pragma once
#include "vpx/vp8cx.h"
#include "vpx/vpx_encoder.h"
#include "vpx_common.h"
#include <erl_nif.h>

typedef struct State {
  vpx_codec_ctx_t codec_context;
  vpx_codec_iface_t *codec_interface;
  vpx_image_t img;
  int encoding_quality;
} State;

#include "_generated/vpx_encoder.h"
