// TODO: sample comment
#include <iostream>
#include <memory>
using namespace std;

template <typename T>
class Widget { public: void draw(); };

int helper(int a) {
    auto w = std::make_shared<Widget<int>>();
    auto u = std::make_unique<int>(1);
    Widget<int> *n = new Widget<int>();
    delete n;
    auto m = std::move(u);
    auto c = static_cast<long>(a);
    auto f = [](int x) { return x; };
    int v[] = {1, 2};
    for (auto x : v) {}
    std::cout << "a string" << a;
    try { helper(1); } catch (...) {}
    return a;
}
