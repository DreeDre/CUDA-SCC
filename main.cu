#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include "test.h"
#include "utils.h"

#define START_NODES 1000
#define STEP_NODES 1000
#define MAX_NODES 10000000
#define EDGES_FACTOR 20
#define NUM_RUNS 10


void generateGraph(int num_nodes, int num_edges, const char *filename) {
    FILE *fp = fopen(filename, "w");
    if (fp == NULL) {
        perror("Error during file opening\n");
        exit(EXIT_FAILURE);
    }

    srand(42);  // seed
    for (int i = 0; i < num_edges; i++) {
        int src = rand() % num_nodes + 1;
        int dst = rand() % num_nodes + 1;
        fprintf(fp, "%d %d\n", src, dst);
    }
    fclose(fp);
}


double getAverageTime(int* (*fun)(CSRGraph *), CSRGraph *graph) {
    double total_time = 0.0;
    for (int i = 0; i < NUM_RUNS; i++) {
        double start = get_time_ms();
        int *scc = fun(graph);
        double end = get_time_ms();
        free(scc);
        total_time += end - start;
    }
    return total_time / NUM_RUNS;
}


int main() {
    double start = get_time_ms();
    FILE *results = fopen("results.csv", "w");
    if (results == NULL) {
        perror("Error during file opening\n");
        return 1;
    }
    fprintf(results, "Nodes,Edges,Avg_Time_Sequential,Avg_Time_ParallelCUDA\n");

    int i = 1;
    for (int num_nodes = START_NODES; num_nodes < MAX_NODES; num_nodes += STEP_NODES) {
        double start2 = get_time_ms();
        
        printf("Experiment %d:\n", i);
        i++;

        int num_edges = num_nodes * EDGES_FACTOR;
        char filename[] = "graph.txt";
            
        generateGraph(num_nodes, num_edges, filename);
        CSRGraph *graph = readCSRGraphFromFile(filename);
        printf("Graph: %d nodes, %d edges\n", graph -> num_nodes, graph -> num_edges);

        double avg_time_seq = getAverageTime(sequential, graph);
        printf("Average CPU exec time: %f ms\n", avg_time_seq);

        double avg_time_cuda = getAverageTime(parallel_cuda, graph);
        printf("Average GPU exec time: %f ms\n", avg_time_cuda);

        fprintf(results, "%d,%d,%.5f,%.5f\n", num_nodes, num_edges, avg_time_seq, avg_time_cuda);

        freeCSRGraph(graph);

        num_nodes = (int)(num_nodes * 1.5);

        printf("Experiment ran in %f ms\n\n", get_time_ms() - start2);
    }

    fclose(results);
    printf("Experiments completed in %f s. Results saved in 'results.csv'.\n", (get_time_ms() - start) / 1000);
    return 0;
}
