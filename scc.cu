#include <stdio.h>
#include "test.h"
#include "utils.h"


int main() {
    CSRGraph *graph = readCSRGraphFromFile("graph.txt");

    printf("Sequantial results:\n");
    test_sequential(graph);
    printf("\n");
    printf("Parallel results:\n");
    test_parallel_cuda(graph);

    freeCSRGraph(graph);
    return 0;
}
