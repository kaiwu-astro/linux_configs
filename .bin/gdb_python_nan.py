'''
start gdb, 
type python,
paste following code,
press control+D to run
'''

import sys
print("Python version:", sys.version)

N = gdb.parse_and_eval("N")
X = [
    0,
    gdb.parse_and_eval("X(1,1:N+5000)"),
    gdb.parse_and_eval("X(2,1:N+5000)"),
    gdb.parse_and_eval("X(3,1:N+5000)"),
]

try:
    import numpy as np
    X = [np.array(X[i]).astype(float) for i in range(1,4)]
    # check nan or inf with numpy
    print("Using NumPy for checking NaN/Inf values")
    for j in range(3):
        print(f"Checking X({j+1},)")
        nan_mask = np.isnan(X[j])
        inf_mask = np.isinf(X[j])
        
        if np.any(nan_mask):
            nan_indices = np.where(nan_mask)[0]
            for idx in nan_indices:
                print(f"X({j+1},{idx+1}) = NaN")
        
        if np.any(inf_mask):
            inf_indices = np.where(inf_mask)[0]
            for idx in inf_indices:
                print(f"X({j+1},{idx+1}) = Inf")
        
        # Print some samples for verification
        for i in range(0, len(X[j]), 100000):
            if i < len(X[j]):
                print(f"X({j+1},{i+1}) = {X[j][i]}")

except ImportError:
    print("Numpy not found. Using built-in packages")
    import math

    for j in range(1, 4):
        print("checking X({0},)".format(j))
        for i in range(1, N+1):
            if i % 100000 == 0:
                print("X({0},{1}) = {2}".format(j, i, X[j][i]))
            val = float(X[j][i])
            if math.isnan(val) or math.isinf(val):
                print("X({0},{1}) = {2}".format(j, i, val))
