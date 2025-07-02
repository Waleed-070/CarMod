#include <iostream>
#include <fstream>
#include <mpi.h>
#include <cuda_runtime.h>

#define FINGERPRINT_SIZE 16
#define MASK_LENGTH 8

void match_fingerprints(unsigned char* d_chunk, unsigned char* d_query, int rows, int* d_result_idx, int* d_result_offset) {
    // Implementation of match_fingerprints function
}

int main(int argc, char** argv) {
    MPI_Init(&argc, &argv);

    int rank, size;
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);

    if (rank == 0) {
        std::cout << "[Master] Loading fingerprint database..." << std::endl;

        std::ifstream infile("fingerprint_database.bin", std::ios::binary);
        if (!infile) {
            std::cerr << "[Master] Cannot open fingerprint_database.bin" << std::endl;
            MPI_Abort(MPI_COMM_WORLD, 1);
        }

        unsigned char* data = new unsigned char[total * FINGERPRINT_SIZE];
        infile.read((char*)data, total * FINGERPRINT_SIZE);
        infile.close();

        std::cout << "[Master] Masked fingerprint to search: ";
        for (int i = 0; i < MASK_LENGTH; i++) std::cout << (int)query[i] << " ";
        std::cout << std::endl;

        // Print first row, first 8 bytes
        std::cout << "[Master] First row, first 8 bytes: ";
        for (int i = 0; i < MASK_LENGTH; ++i) std::cout << (int)data[i] << " ";
        std::cout << std::endl;

        for (int i = 1; i < size; ++i) {
            int start = (i - 1) * chunk_size;
            int count = (i == size - 1) ? total - start : chunk_size;

            MPI_Send(&start, 1, MPI_INT, i, 5, MPI_COMM_WORLD); // Send actual start index
            MPI_Send(query, MASK_LENGTH, MPI_UNSIGNED_CHAR, i, 0, MPI_COMM_WORLD);
            MPI_Send(&count, 1, MPI_INT, i, 1, MPI_COMM_WORLD);
            MPI_Send(data + start * FINGERPRINT_SIZE, count * FINGERPRINT_SIZE, MPI_UNSIGNED_CHAR, i, 2, MPI_COMM_WORLD);
        }
    } else {
        MPI_Status status;
        unsigned char local_query[MASK_LENGTH];
        int local_rows;
        int start_index;

        MPI_Recv(&start_index, 1, MPI_INT, 0, 5, MPI_COMM_WORLD, &status);
        MPI_Recv(local_query, MASK_LENGTH, MPI_UNSIGNED_CHAR, 0, 0, MPI_COMM_WORLD, &status);
        MPI_Recv(&local_rows, 1, MPI_INT, 0, 1, MPI_COMM_WORLD, &status);

        unsigned char* local_data = new unsigned char[local_rows * FINGERPRINT_SIZE];
        MPI_Recv(local_data, local_rows * FINGERPRINT_SIZE, MPI_UNSIGNED_CHAR, 0, 2, MPI_COMM_WORLD, &status);

        // Print received query
        std::cout << "[Worker " << rank << "] Received query: ";
        for (int i = 0; i < MASK_LENGTH; ++i) std::cout << (int)local_query[i] << " ";
        std::cout << std::endl;
        // Print first row, first 8 bytes
        std::cout << "[Worker " << rank << "] First row, first 8 bytes: ";
        for (int i = 0; i < MASK_LENGTH; ++i) std::cout << (int)local_data[i] << " ";
        std::cout << std::endl;

        unsigned char *d_chunk, *d_query;
        int *d_result_idx, *d_result_offset;
        int h_result_idx = -1, h_result_offset = -1;

        cudaError_t err;
        err = cudaMalloc(&d_chunk, local_rows * FINGERPRINT_SIZE);
        if (err != cudaSuccess) { std::cerr << "cudaMalloc d_chunk failed: " << cudaGetErrorString(err) << std::endl; MPI_Abort(MPI_COMM_WORLD, 1); }
        err = cudaMalloc(&d_query, MASK_LENGTH);
        if (err != cudaSuccess) { std::cerr << "cudaMalloc d_query failed: " << cudaGetErrorString(err) << std::endl; MPI_Abort(MPI_COMM_WORLD, 1); }
        err = cudaMalloc(&d_result_idx, sizeof(int));
        if (err != cudaSuccess) { std::cerr << "cudaMalloc d_result_idx failed: " << cudaGetErrorString(err) << std::endl; MPI_Abort(MPI_COMM_WORLD, 1); }
        err = cudaMalloc(&d_result_offset, sizeof(int));
        if (err != cudaSuccess) { std::cerr << "cudaMalloc d_result_offset failed: " << cudaGetErrorString(err) << std::endl; MPI_Abort(MPI_COMM_WORLD, 1); }

        err = cudaMemcpy(d_chunk, local_data, local_rows * FINGERPRINT_SIZE, cudaMemcpyHostToDevice);
        if (err != cudaSuccess) { std::cerr << "cudaMemcpy d_chunk failed: " << cudaGetErrorString(err) << std::endl; MPI_Abort(MPI_COMM_WORLD, 1); }
        err = cudaMemcpy(d_query, local_query, MASK_LENGTH, cudaMemcpyHostToDevice);
        if (err != cudaSuccess) { std::cerr << "cudaMemcpy d_query failed: " << cudaGetErrorString(err) << std::endl; MPI_Abort(MPI_COMM_WORLD, 1); }
        err = cudaMemcpy(d_result_idx, &h_result_idx, sizeof(int), cudaMemcpyHostToDevice);
        if (err != cudaSuccess) { std::cerr << "cudaMemcpy d_result_idx failed: " << cudaGetErrorString(err) << std::endl; MPI_Abort(MPI_COMM_WORLD, 1); }
        err = cudaMemcpy(d_result_offset, &h_result_offset, sizeof(int), cudaMemcpyHostToDevice);
        if (err != cudaSuccess) { std::cerr << "cudaMemcpy d_result_offset failed: " << cudaGetErrorString(err) << std::endl; MPI_Abort(MPI_COMM_WORLD, 1); }

        int threads = 256;
        int blocks = (local_rows + threads - 1) / threads;
        match_fingerprints<<<blocks, threads>>>(d_chunk, d_query, local_rows, d_result_idx, d_result_offset);
        err = cudaDeviceSynchronize();
        if (err != cudaSuccess) { std::cerr << "cudaDeviceSynchronize failed: " << cudaGetErrorString(err) << std::endl; MPI_Abort(MPI_COMM_WORLD, 1); }

        err = cudaMemcpy(&h_result_idx, d_result_idx, sizeof(int), cudaMemcpyDeviceToHost);
        if (err != cudaSuccess) { std::cerr << "cudaMemcpy d_result_idx (to host) failed: " << cudaGetErrorString(err) << std::endl; MPI_Abort(MPI_COMM_WORLD, 1); }
        err = cudaMemcpy(&h_result_offset, d_result_offset, sizeof(int), cudaMemcpyDeviceToHost);
        if (err != cudaSuccess) { std::cerr << "cudaMemcpy d_result_offset (to host) failed: " << cudaGetErrorString(err) << std::endl; MPI_Abort(MPI_COMM_WORLD, 1); }

        if (h_result_idx != -1) {
            std::cout << "[Worker " << rank << "] Match at local index " << h_result_idx
                      << ", offset " << h_result_offset << std::endl;
        } else {
            std::cout << "[Worker " << rank << "] No match found." << std::endl;
        }

        int global_index = (h_result_idx == -1) ? -1 : start_index + h_result_idx;
        MPI_Send(&global_index, 1, MPI_INT, 0, 3, MPI_COMM_WORLD);
        MPI_Send(&h_result_offset, 1, MPI_INT, 0, 4, MPI_COMM_WORLD);

        delete[] local_data;
        cudaFree(d_chunk);
        cudaFree(d_query);
        cudaFree(d_result_idx);
        cudaFree(d_result_offset);
    }

    MPI_Finalize();
    return 0;
} 