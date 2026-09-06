// c++: type system, closures, and numeric model
#include <iostream>
#include <vector>
#include <functional>
#include <limits>
#include <iomanip>
using namespace std;

// closures require an explicit capture list
void closureCapture() {
    vector<function<int()>> byValue;
    for (int i = 0; i < 3; i++) {
        byValue.push_back([i]() { return i; });   // copy of i at creation
    }

    int shared = 0;
    vector<function<int()>> byRef;
    for (int k = 0; k < 3; k++) {
        shared = k;
        byRef.push_back([&shared]() { return shared; });  // refers to one variable
    }

    cout << "closures (capture by value [i]): ";
    for (auto &f : byValue) cout << f() << " ";
    cout << "\nclosures (capture by ref [&]):   ";
    for (auto &f : byRef) cout << f() << " ";
    cout << "\n";
}

void typeSystem() {
    int    i = 5;
    double d = 3.0;
    cout << "\n  5 + 3.0 (int + double) -> " << fixed << setprecision(1) << i + d
         << "  (result is " << sizeof(i + d) << " bytes: promoted to double)\n"
         << defaultfloat;

    // implicit narrowing is permitted and silently truncates
    double pi = 3.99;
    int truncated = pi;
    cout << "  int t = 3.99          -> " << truncated << "  (silent truncation)\n";

    // string + int does not compile; see type_error.cpp in this directory
    cout << "  \"5\" + 3              -> rejected at compile time\n";
}

void numericModel() {
    int  maxInt = numeric_limits<int>::max();
    // signed overflow is undefined behavior; unsigned wraps by definition
    unsigned int umax = numeric_limits<unsigned int>::max();
    cout << "\n  INT_MAX               = " << maxInt << "\n";
    cout << "  UINT_MAX              = " << umax << "\n";
    cout << "  UINT_MAX + 1          = " << umax + 1 << "  (defined wraparound)\n";
    cout << "  0.1 + 0.2             = " << setprecision(17) << 0.1 + 0.2 << "\n";
    cout << "  sizeof(int)           = " << sizeof(int) << " bytes\n";
}

int main() {
    closureCapture();
    typeSystem();
    numericModel();
    return 0;
}
