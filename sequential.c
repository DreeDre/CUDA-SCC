#include "utils.h"
#include <stdbool.h>


int *sequential(CSRGraph *graph) {
    int *discover = (int *)calloc(graph -> num_nodes, sizeof(int));
    int *low = (int *)calloc(graph -> num_nodes, sizeof(int));
    bool *inStack = (bool *)calloc(graph -> num_nodes, sizeof(bool));
    int *stack = (int *)malloc(graph -> num_nodes * sizeof(int));
    int *work_stack = (int *)malloc(graph -> num_nodes * sizeof(int));
    int *parent = (int *)malloc(graph -> num_nodes * sizeof(int));
    int *index = (int *)calloc(graph -> num_nodes, sizeof(int));
    int *scc = (int *)malloc(graph -> num_nodes * sizeof(int));
    
    int time = 0, stackSize = 0, sccCount = 0;
    
    for (int i = 0; i < graph -> num_nodes; i++) {
        discover[i] = -1;
        low[i] = -1;
        scc[i] = -1;
        parent[i] = -1;
    }
    
    for (int startNode = 0; startNode < graph -> num_nodes; startNode++) {
        if (discover[startNode] != -1) continue;
        
        int work_top = 0;
        work_stack[work_top++] = startNode;
        
        while (work_top > 0) {
            int u = work_stack[work_top - 1];
            
            if (discover[u] == -1) {
                discover[u] = low[u] = ++time;
                stack[stackSize++] = u;
                inStack[u] = true;
                index[u] = graph -> row_ptr[u];
            }
            
            bool done = true;
            for (; index[u] < graph -> row_ptr[u + 1]; index[u]++) {
                int v = graph -> col_idx[index[u]];
                
                if (discover[v] == -1) {
                    parent[v] = u;
                    work_stack[work_top++] = v;
                    done = false;
                    break;
                } else if (inStack[v]) {
                    low[u] = (low[u] < discover[v]) ? low[u] : discover[v];
                }
            }
            
            if (done) {
                work_top--;
                if (parent[u] != -1) {
                    low[parent[u]] = (low[parent[u]] < low[u]) ? low[parent[u]] : low[u];
                }
                if (low[u] == discover[u]) {
                    int v;
                    do {
                        v = stack[--stackSize];
                        inStack[v] = false;
                        scc[v] = sccCount;
                    } while (v != u);
                    sccCount++;
                }
            }
        }
    }
    
    free(discover);
    free(low);
    free(inStack);
    free(stack);
    free(work_stack);
    free(parent);
    free(index);

    return scc;
}


void test_sequential(CSRGraph *graph) {
    int *scc = sequential(graph);

    printf("Node -> SCC\n");
    for (int i = 0; i < graph -> num_nodes; i++) {
        printf("%d -> %d\n", i, scc[i]);
    }
    
    free(scc);
}
