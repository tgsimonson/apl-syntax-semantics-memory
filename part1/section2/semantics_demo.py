# python: type system, closures, and numeric model

def closure_capture():
    # late binding: all closures share the same variable cell
    fns_late = []
    for i in range(3):
        fns_late.append(lambda: i)
    # default-argument idiom forces capture by value at definition time
    fns_early = []
    for i in range(3):
        fns_early.append(lambda i=i: i)
    return [f() for f in fns_late], [f() for f in fns_early]

def type_system():
    results = []
    x = 5
    results.append(("rebind int to str", type(x).__name__))
    x = "five"
    results.append(("after rebinding", type(x).__name__))
    try:
        _ = "5" + 3
    except TypeError as e:
        results.append(("'5' + 3", "TypeError: " + str(e)))
    results.append(("5 + 3.0", repr(5 + 3.0)))
    return results

def numeric_model():
    # arbitrary precision: no overflow
    big = 2 ** 63
    return big, big * big, (2**31 - 1) + 1

if __name__ == "__main__":
    late, early = closure_capture()
    print("closures (late binding):  ", late)
    print("closures (default arg):   ", early)
    print()
    for label, val in type_system():
        print(f"  {label:22} -> {val}")
    print()
    b, bsq, edge = numeric_model()
    print("2**63          =", b)
    print("(2**63)**2     =", bsq)
    print("(2**31-1)+1    =", edge)
