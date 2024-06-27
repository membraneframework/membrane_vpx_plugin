#pragma once
#include "vpx/vp8dx.h"
#include "vpx/vpx_decoder.h"
#include <erl_nif.h>

typedef struct State {
  vpx_codec_ctx_t codec_context;
  vpx_codec_iface_t *codec_interface;
} State;

typedef struct Dimensions {
  unsigned int width;
  unsigned int height;
} Dimensions;

#include "_generated/vpx_decoder.h"