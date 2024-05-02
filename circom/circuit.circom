pragma circom 2.1.6;
//include "node_modules/circomlib/circuits/comparators.circom";

template IsZero() {
    signal input in;
    signal output out;

    signal inv;

    inv <-- in!=0 ? 1/in : 0;

    out <== -in*inv +1;
    in*out === 0;
}

template IsEqual() {
    signal input in[2];
    signal output out;

    component isz = IsZero();

    in[1] - in[0] ==> isz.in;

    isz.out ==> out;
}

template accuracy (m) {
    signal input a1[m];
    signal input a2[m];
    signal input num;
    signal mid[m];
    signal output out;

    var count = 0;
    
    for (var i=0; i < m; i++) {
        mid[i] <== a1[i] - a2[i];   
        var check = IsZero()(mid[i]);
        count += check;
    }

    var isEqual = IsEqual()([count, num]);
    out <== isEqual;

}

component main = accuracy(100);
