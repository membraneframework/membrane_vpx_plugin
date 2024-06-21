#pragma once
#include "vpx/vpx_codec.h"
#include "vpx/vpx_image.h"
#include <unifex/payload.h>
#include <unifex/unifex.h>

typedef struct Dimensions {
  unsigned int width;
  unsigned int height;
} Dimensions;

UNIFEX_TERM result_error(
    UnifexEnv *env,
    const char *reason,
    UNIFEX_TERM (*result_error_fun)(UnifexEnv *, const char *),
    vpx_codec_ctx_t *codec_context,
    void *state
);

typedef enum ConversionType { IMAGE_TO_RAW_FRAME, RAW_FRAME_TO_IMAGE } ConversionType;

Dimensions get_plane_dimensions(const vpx_image_t *img, int plane);

void free_payloads(UnifexPayload **payloads, unsigned int payloads_cnt);

void convert_between_image_and_raw_frame(
    vpx_image_t *img, UnifexPayload *raw_frame, ConversionType conversion_type
);