// c++: demonstrates that a type error caught at runtime in Python and
// silently coerced in JavaScript is rejected by the compiler here
#include <string>
int main() {
    std::string s = "5";
    int n = 3;
    int result = s + n;   // no viable conversion
    return result;
}
