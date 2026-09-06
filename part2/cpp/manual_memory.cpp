// c++: manual memory management, leaks, and dangling pointers
#include <iostream>
#include <cstring>
#include <chrono>
using namespace std;
using namespace std::chrono;

const int N = 200000;

// correct: every new is matched by a delete
long long correctAllocation() {
    long long sum = 0;
    for (int i = 0; i < N; i++) {
        int *block = new int[64];
        for (int j = 0; j < 64; j++) block[j] = i + j;
        sum += block[0];
        delete[] block;          // caller is responsible for this
    }
    return sum;
}

// deliberate leak: allocation with no matching delete
void leakMemory(int blocks) {
    for (int i = 0; i < blocks; i++) {
        int *leaked = new int[256];
        leaked[0] = i;
        // no delete[] -- 256 * 4 bytes lost per iteration
    }
}

// deliberate dangling pointer: read after free
int danglingPointer() {
    int *p = new int(42);
    delete p;                    // memory returned to allocator
    return *p;                   // undefined behavior: read of freed memory
}

int main(int argc, char **argv) {
    auto t0 = high_resolution_clock::now();
    long long s = correctAllocation();
    auto t1 = high_resolution_clock::now();
    cout << "correct alloc/free of " << N << " blocks, checksum " << s << "\n";
    cout << "elapsed: " << duration_cast<milliseconds>(t1 - t0).count() << " ms\n";

    if (argc > 1 && strcmp(argv[1], "--leak") == 0) {
        leakMemory(1000);
        cout << "leaked 1000 blocks of 256 ints (1,024,000 bytes)\n";
    }
    if (argc > 1 && strcmp(argv[1], "--dangle") == 0) {
        cout << "dangling read returned: " << danglingPointer() << "\n";
    }
    return 0;
}
