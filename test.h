#ifndef TEST_H
#define TEST_H

#include <stdio.h>
#include <stdlib.h>
#include "utils.h"

#ifdef __cplusplus
extern "C" {
#endif

int *sequential(CSRGraph *graph);
int *parallel_cuda(CSRGraph *graph);
void test_parallel_cuda(CSRGraph *graph);
void test_sequential(CSRGraph *graph);

#ifdef __cplusplus
}
#endif

#endif