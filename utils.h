#ifndef UTILS_H
#define UTILS_H

#include <stdio.h>
#include <stdlib.h>

typedef struct {
    int *row_ptr;
    int *col_idx;   
    int num_nodes;
    int num_edges;
} CSRGraph;

#ifdef __cplusplus
extern "C" {
#endif

CSRGraph* readCSRGraphFromFile(const char *filename);
CSRGraph* transposeCSRGraph(const CSRGraph *graph);
void printCSRGraph(CSRGraph *graph);
void freeCSRGraph(CSRGraph *graph);
double get_time_ms();

#ifdef __cplusplus
}
#endif

#endif