all:
	nvcc -c cuda.cu -o cuda.o
	gcc -c sequential.c -o sequential.o
	gcc -c utils.c -o utils.o
	nvcc main.cu utils.o cuda.o sequential.o -o main
	nvcc scc.cu utils.o cuda.o sequential.o -o scc

test:
	./scc

experiments: 
	./main
	
clean:
	rm -f *.o main scc utils