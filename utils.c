#include "utils.h"
#include <sys/time.h>
#include <stdio.h>
#include <stdlib.h>


CSRGraph* readCSRGraphFromFile(const char *filename) {
    double start = get_time_ms();
    FILE *file = fopen(filename, "r");
    if (!file) {
        perror("Error during file opening\n");
        return NULL;
    }

    int max_nodes = -1, num_edges = 0;
    int src, dst;
    
    while (fscanf(file, "%d %d", &src, &dst) == 2) {
        if(src > max_nodes) max_nodes = src;
        if(dst > max_nodes) max_nodes = dst;
        num_edges++;
    }
    
    int num_nodes = max_nodes; 
    
    rewind(file);

    int *row_ptr = (int*)calloc(num_nodes + 1, sizeof(int));
    int *col_idx = (int*)malloc(num_edges * sizeof(int)); 

    while (fscanf(file, "%d %d", &src, &dst) == 2){
        row_ptr[src]++;
    }

    for (int i = 1; i <= num_nodes; i++) {
        row_ptr[i] += row_ptr[i - 1];
    }
    
    rewind(file);

    int *current_pos = (int*)calloc(num_nodes, sizeof(int));
    
    while (fscanf(file, "%d %d", &src, &dst) == 2) {
        int pos = row_ptr[src - 1] + current_pos[src - 1];
        col_idx[pos] = dst - 1;
        current_pos[src - 1]++;
    }
    
    free(current_pos);
    fclose(file);

    CSRGraph *graph = (CSRGraph*)malloc(sizeof(CSRGraph));
    graph -> row_ptr = row_ptr;
    graph -> col_idx = col_idx;
    graph -> num_nodes = num_nodes;
    graph -> num_edges = num_edges;
    double end = get_time_ms();
    printf("Graph read from file '%s' in %f ms\n", filename,  end - start);
    return graph;
}


CSRGraph* transposeCSRGraph(const CSRGraph *graph) {
    int n = graph -> num_nodes;
    int m = graph -> num_edges;

    CSRGraph *tgraph = (CSRGraph*) malloc(sizeof(CSRGraph));
    tgraph -> num_nodes = n;
    tgraph -> num_edges = m;
    tgraph -> row_ptr = (int*) calloc(n + 1, sizeof(int));
    tgraph -> col_idx = (int*) malloc(m * sizeof(int));

    for (int u = 0; u < n; u++) {
        for (int i = graph -> row_ptr[u]; i < graph -> row_ptr[u + 1]; i++) {
            int v = graph -> col_idx[i];
            tgraph -> row_ptr[v + 1]++;
        }
    }

    for (int i = 0; i < n; i++) {
        tgraph -> row_ptr[i + 1] += tgraph -> row_ptr[i];
    }

    int *counter = (int*) calloc(n, sizeof(int));
    for (int u = 0; u < n; u++) {
        for (int i = graph -> row_ptr[u]; i < graph -> row_ptr[u + 1]; i++) {
            int v = graph -> col_idx[i];
            int pos = tgraph -> row_ptr[v] + counter[v];
            tgraph -> col_idx[pos] = u;
            counter[v]++;
        }
    }
    free(counter);

    return tgraph;
}


void printCSRGraph(CSRGraph *graph) {
    printf("Number of nodes: %d\n", graph -> num_nodes);
    printf("Number of edges: %d\n", graph -> num_edges);

    printf("Nodes array:\n");
    for (int i = 0; i < graph -> num_nodes; i++) {
        printf("%d ", graph -> row_ptr[i]);
    }
    printf("\n");

    printf("Edges array:\n");
    for (int i = 0; i < graph -> num_edges; i++) {
        printf("%d ", graph -> col_idx[i]);
    }
    printf("\n");
}


void freeCSRGraph(CSRGraph *graph) {
    free(graph -> row_ptr);
    free(graph -> col_idx);
}


double get_time_ms() {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return ((tv.tv_sec * 1000000LL) + tv.tv_usec) / 1000.0;
}

/*
int main(){
    const char *filename = "graph.txt";
    CSRGraph *graph = readCSRGraphFromFile(filename);
    printCSRGraph(graph);
    freeCSRGraph(graph);
    return 0;
}*/

