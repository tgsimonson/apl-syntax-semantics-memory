// javascript: type system, closures, and numeric model

function closureCapture() {
    // var is function-scoped: all three closures share one binding
    const fnsVar = [];
    for (var i = 0; i < 3; i++) {
        fnsVar.push(() => i);
    }
    // let is block-scoped: a fresh binding is created per iteration
    const fnsLet = [];
    for (let j = 0; j < 3; j++) {
        fnsLet.push(() => j);
    }
    return [fnsVar.map(f => f()), fnsLet.map(f => f())];
}

function typeSystem() {
    return [
        ["'5' + 3",        JSON.stringify("5" + 3)],
        ["'5' - 3",        JSON.stringify("5" - 3)],
        ["[] + {}",        JSON.stringify([] + {})],
        ["1 == '1'",       String(1 == "1")],
        ["1 === '1'",      String(1 === "1")],
        ["typeof (5)",     typeof 5],
        ["typeof ('five')", typeof "five"],
    ];
}

function numericModel() {
    return {
        maxSafe: Number.MAX_SAFE_INTEGER,
        overflow: Number.MAX_SAFE_INTEGER + 2,
        int32wrap: (2147483647 | 0) + 1,
        pointOne: 0.1 + 0.2,
    };
}

const [varRes, letRes] = closureCapture();
console.log("closures (var):", varRes);
console.log("closures (let):", letRes);
console.log();
for (const [label, val] of typeSystem()) {
    console.log("  " + label.padEnd(22) + " -> " + val);
}
console.log();
const n = numericModel();
console.log("MAX_SAFE_INTEGER      =", n.maxSafe);
console.log("MAX_SAFE_INTEGER + 2  =", n.overflow);
console.log("(2147483647|0) + 1    =", n.int32wrap);
console.log("0.1 + 0.2             =", n.pointOne);
