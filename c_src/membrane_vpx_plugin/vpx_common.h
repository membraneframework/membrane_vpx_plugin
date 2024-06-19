#pragma once
#include "vpx/vpx_image.h"
#include <unifex/payload.h>
#include <unifex/unifex.h>

typedef struct Dimensions {
  unsigned int width;
  unsigned int height;
} Dimensions;

Dimensions get_plane_dimensions(const vpx_image_t *img, int plane);

void free_payloads(UnifexPayload **payloads, unsigned int payloads_cnt);