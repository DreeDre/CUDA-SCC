#include <stdio.h>
#include <stdlib.h>
#include <cuda_runtime.h>
#include "utils.h"
#include "test.h"

#define THREADS_PER_BLOCK 256


__global__ void forwardPropagationKernel(const int num_nodes, const int *row_ptr, const int *col_idx, int *fwd_label, const int *active, int *changed) {
    int tid = blockIdx.x * blockDim.x + threadIdx.x;
    if (tid >= num_nodes || !active[tid]){
        return;
    }

    for (int i = row_ptr[tid]; i < row_ptr[tid+1]; i++) {
        int neighbour = col_idx[i];
        if (active[neighbour]) {
            int newVal = fwd_label[neighbour];
            int prev = atomicMin(&fwd_label[tid], newVal);
            if (newVal < prev) {
                atomicExch(changed, 1);
            }
        }
    }
}


__global__ void backwardPropagationKernel(const int num_nodes, const int *t_row_ptr, const int *t_col_idx, int *bwd_label, const int *active, const int *fwd_label, int *changed) {
    int tid = blockIdx.x * blockDim.x + threadIdx.x;
    if (tid >= num_nodes || !active[tid]){
        return;
    }

    for (int i = t_row_ptr[tid]; i < t_row_ptr[tid+1]; i++) {
        int neighbour = t_col_idx[i];
        if (active[neighbour] && (fwd_label[tid] == fwd_label[neighbour])) {
            int newVal = bwd_label[neighbour];
            int prev = atomicMin(&bwd_label[tid], newVal);
            if (newVal < prev) {
                atomicExch(changed, 1);
            }
        }
    }
}


__global__ void resetLabelsKernel(int num_nodes, int *fwd_label, int *bwd_label, const int *active) {
    int tid = blockIdx.x * blockDim.x + threadIdx.x;
    if (tid < num_nodes && active[tid]) {
        fwd_label[tid] = tid;
        bwd_label[tid] = tid;
    }
}


__global__ void intersectionKernel(const int num_nodes, const int *fwd_label, const int *bwd_label, int *active, int *scc) {
    int tid = blockIdx.x * blockDim.x + threadIdx.x;
    if (tid >= num_nodes || !active[tid]) {
        return;
    }

    if (fwd_label[tid] == bwd_label[tid]) {
        scc[tid] = fwd_label[tid];
        active[tid] = 0;
    }
}


int *parallel_cuda(CSRGraph *graph) {
    CSRGraph *tGraph = transposeCSRGraph(graph);

    int *d_row_ptr, *d_col_idx, *d_t_row_ptr, *d_t_col_idx;
    cudaMalloc(&d_row_ptr, (graph -> num_nodes + 1) * sizeof(int));
    cudaMalloc(&d_col_idx, graph -> num_edges * sizeof(int));
    cudaMemcpy(d_row_ptr, graph -> row_ptr, (graph -> num_nodes + 1) * sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(d_col_idx, graph -> col_idx, graph -> num_edges * sizeof(int), cudaMemcpyHostToDevice);

    cudaMalloc(&d_t_row_ptr, (tGraph -> num_nodes + 1) * sizeof(int));
    cudaMalloc(&d_t_col_idx, tGraph -> num_edges * sizeof(int));
    cudaMemcpy(d_t_row_ptr, tGraph -> row_ptr, (tGraph -> num_nodes + 1) * sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(d_t_col_idx, tGraph -> col_idx, tGraph -> num_edges * sizeof(int), cudaMemcpyHostToDevice);

    int *h_scc = (int*)malloc(graph -> num_nodes * sizeof(int));

    int *h_active = (int*)malloc(graph -> num_nodes * sizeof(int));
    for (int i = 0; i < graph -> num_nodes; i++){
        h_active[i] = 1;
    }

    int *d_fwd_label, *d_bwd_label, *d_active, *d_scc;
    cudaMalloc(&d_fwd_label, graph -> num_nodes * sizeof(int));
    cudaMalloc(&d_bwd_label, graph -> num_nodes * sizeof(int));
    cudaMalloc(&d_active, graph -> num_nodes * sizeof(int));
    cudaMalloc(&d_scc, graph -> num_nodes * sizeof(int));

    int *h_init = (int*)malloc(graph -> num_nodes * sizeof(int));
    for (int i = 0; i < graph -> num_nodes; i++){
        h_init[i] = i;
    }

    cudaMemcpy(d_fwd_label, h_init, graph -> num_nodes * sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(d_bwd_label, h_init, graph -> num_nodes * sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(d_active, h_active, graph -> num_nodes * sizeof(int), cudaMemcpyHostToDevice);
    free(h_init);

    int blocks = (graph -> num_nodes + THREADS_PER_BLOCK - 1) / THREADS_PER_BLOCK;
    int h_changed;
    int *d_changed;
    cudaMalloc(&d_changed, sizeof(int));

    bool done = false;
    while (!done) {
        h_changed = 0;
        cudaMemcpy(d_changed, &h_changed, sizeof(int), cudaMemcpyHostToDevice);

        // forward process
        do {
            h_changed = 0;
            cudaMemcpy(d_changed, &h_changed, sizeof(int), cudaMemcpyHostToDevice);

            forwardPropagationKernel<<<blocks, THREADS_PER_BLOCK>>>(graph -> num_nodes, d_row_ptr, d_col_idx, d_fwd_label, d_active, d_changed);

            cudaMemcpy(&h_changed, d_changed, sizeof(int), cudaMemcpyDeviceToHost);
        } while (h_changed);

        // backward process
        do {
            h_changed = 0;
            cudaMemcpy(d_changed, &h_changed, sizeof(int), cudaMemcpyHostToDevice);

            backwardPropagationKernel<<<blocks, THREADS_PER_BLOCK>>>(graph -> num_nodes, d_t_row_ptr, d_t_col_idx, d_bwd_label, d_active, d_fwd_label, d_changed);

            cudaMemcpy(&h_changed, d_changed, sizeof(int), cudaMemcpyDeviceToHost);
        } while (h_changed);

        intersectionKernel<<<blocks, THREADS_PER_BLOCK>>>(graph -> num_nodes, d_fwd_label, d_bwd_label, d_active, d_scc);

        resetLabelsKernel<<<blocks, THREADS_PER_BLOCK>>>(graph -> num_nodes, d_fwd_label, d_bwd_label, d_active);

        int *h_temp = (int*)malloc(graph -> num_nodes * sizeof(int));
        cudaMemcpy(h_temp, d_active, graph -> num_nodes * sizeof(int), cudaMemcpyDeviceToHost);

        int activeCount = 0;
        for (int i = 0; i < graph -> num_nodes; i++) {
            activeCount += h_temp[i];
        }
        free(h_temp);

        if (activeCount == 0) {
            done = true;
        }
    }

    cudaMemcpy(h_scc, d_scc, graph -> num_nodes * sizeof(int), cudaMemcpyDeviceToHost);
    
    cudaFree(d_fwd_label);
    cudaFree(d_bwd_label);
    cudaFree(d_active);
    cudaFree(d_scc);
    cudaFree(d_changed);
    cudaFree(d_row_ptr);
    cudaFree(d_col_idx);
    cudaFree(d_t_row_ptr);
    cudaFree(d_t_col_idx);
    free(h_active);
    freeCSRGraph(tGraph);

    return h_scc;
}


void test_parallel_cuda(CSRGraph *graph) {
    int *scc = parallel_cuda(graph);

    printf("Node -> SCC\n");
    for (int i = 0; i < graph -> num_nodes; i++) {
        printf("%d -> %d\n", i, scc[i]);
    }

    free(scc);
}
