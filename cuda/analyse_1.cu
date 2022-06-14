#include <iostream>
#include <iomanip>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
using namespace std;
const int X = 1024;
size_t threadsPerBlock;
size_t numberOfBlocks;
//  Initial array
void A_reset(float *A)
{
    for (int i = 0; i < X; i++)
    {
        for (int j = 0; j < i; j++)
            A[i*X+j] = 0;
        A[i*X+i] = 1.0;
        for (int j = i + 1; j < X; j++)
            A[i*X+j] = rand();
    }
    for (int k = 0; k < X; k++)
        for (int i = k + 1; i < X; i++)
            for (int j = 0; j < X; j++)
                A[i*X+j] += A[k*X+j];
}

// serial
void normal(int n, float *A)
{
    for (int k = 0; k < n; k++)
    {
        for (int j = k + 1; j < n; j++)
        {
            A[k*n+j] /= A[k*n+k];
        }
        A[k*n+k] = 1.0;
        for (int i = k + 1; i < n; i++)
        {
            for (int j = k + 1; j < n; j++)
            {
                A[i*n+j] -= A[i*n+k] * A[k*n+j];
            }
            A[i*n+k] = 0;
        }
    }
}
__global__ void division_kernel(float *A, int k, int n)
{
    int index = threadIdx.x + blockIdx.x * blockDim.x;
    int stride = blockDim.x * gridDim.x;

    for (int i = index+k+1; i < n ; i += stride)
    {
        float element = A[k*n+k];
        float temp = A[k*n+i];
        //请同学们思考，如果分配的总线程数小于 N 应该怎么办？
        A[k*n+i] = (float)temp / element;
    }
    return;
}

__global__ void eliminate_kernel(float *A, int k, int N)
{
    int tx = blockDim.x * blockIdx.x + threadIdx.x;
    if (tx == 0)
        A[k*N+k] = 1;    //对角线元素设为 1
    int row = k + 1 + blockIdx.x; //每个块负责一行
    while (row < N)
    {
        int tid = threadIdx.x;
        while (k + 1 + tid < N)
        {
            int col = k + 1 + tid;
            float temp_1 = A[row*N+col];
            float temp_2 = A[row*N+k];
            float temp_3 = A[k*N+col];
            A[row*N+col] = temp_1 - temp_2 * temp_3;
            tid = tid + blockDim.x;
        }
        __syncthreads(); //块内同步
        if (threadIdx.x == 0)
        {
            A[row*N+k] = 0;
        }
        row += gridDim.x;
    }
    return;
}

//并行算法
void sp(int n, float *A)
{
    int deviceId;
    int numberOfSMs;

    cudaGetDevice(&deviceId);
    cudaDeviceGetAttribute(&numberOfSMs, cudaDevAttrMultiProcessorCount, deviceId);

    threadsPerBlock = 32;
    numberOfBlocks = 32 * numberOfSMs;

    // size_t size = n * n * sizeof(float);
    // float **A_d;
    // cudaMalloc((void **)&A_d, size);
    // cudaMemcpy(A_d, A, size, cudaMemcpyHostToDevice);

    for (int k = 0; k < n; k++)
    {
        division_kernel<<<numberOfBlocks, threadsPerBlock>>>(A, k, n); //负责除法任务的核函数
        cudaDeviceSynchronize();                                 // CPU 与 GPU 之间的同步函数
        // ret = cudaGetLastError();
        // if (ret != cudaSuccess)
        // {
        //     printf("division_kernel failed, %s\n", cudaGetErrorString(ret));
        // }
        eliminate_kernel<<<numberOfBlocks, threadsPerBlock>>>(A, k, n); //负责消去任务的核函数
        cudaDeviceSynchronize();
        // ret = cudaGetLastError();
        // if (ret != cudaSuccess)
        // {
        //     printf("eliminate_kernel failed, %s\n", cudaGetErrorString(ret));
        // }
    }

    //cudaMemcpy(A, A_d, size, cudaMemcpyDeviceToHost);

    //cudaFree(A);

}
int main()
{
    
    size_t size = X * X * sizeof(float);
    float *A;
    cudaMallocManaged(&A, size);
    
   
    A_reset(A);
        
    sp(X, A);
    cudaFree(A);
    cout << "hello" << endl;
    return 0;
}