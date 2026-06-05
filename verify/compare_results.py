#!/usr/bin/env python3
"""
Compare RTL simulation output with golden model.

Usage:
    python3 verify/compare_results.py --seed 42
"""

import argparse
import sys
import os
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from golden_model import (
    load_test_vectors,
    compute_errors,
    q88_to_float,
)


def load_rtl_output(filename, S=256, d=64):
    """Load RTL output from hex file."""
    values = []
    with open(filename, 'r') as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('//'):
                values.append(int(line, 16))

    # Convert to int16 array
    arr = np.array(values, dtype=np.int16)
    if len(arr) != S * d:
        print(f"Warning: Expected {S*d} values, got {len(arr)}")
        # Pad or truncate
        if len(arr) < S * d:
            arr = np.pad(arr, (0, S*d - len(arr)))
        else:
            arr = arr[:S*d]

    return arr.reshape(S, d)


def main():
    parser = argparse.ArgumentParser(description='Compare RTL output with golden')
    parser.add_argument('--seed', type=int, default=42, help='Random seed')
    parser.add_argument('--S', type=int, default=256, help='Sequence length')
    parser.add_argument('--d', type=int, default=64, help='Head dimension')

    args = parser.parse_args()

    print("="*60)
    print("RTL vs Golden Model Comparison")
    print("="*60)
    print(f"Parameters: S={args.S}, d={args.d}, seed={args.seed}")

    # Load golden output
    golden_file = f"verify/mem_O_golden_seed{args.seed}.hex"
    if not os.path.exists(golden_file):
        print(f"Error: Golden file not found: {golden_file}")
        print("Run 'make golden' first")
        return 1

    O_golden = load_rtl_output(golden_file, args.S, args.d)
    print(f"\nGolden output loaded: {golden_file}")
    print(f"  Shape: {O_golden.shape}")
    print(f"  Range: [{O_golden.min()}, {O_golden.max()}]")

    # Load RTL output
    rtl_file = f"verify/mem_O_rtl_seed{args.seed}.hex"
    if not os.path.exists(rtl_file):
        print(f"\nError: RTL output file not found: {rtl_file}")
        print("Run RTL simulation first to generate output")
        return 1

    O_rtl = load_rtl_output(rtl_file, args.S, args.d)
    print(f"\nRTL output loaded: {rtl_file}")
    print(f"  Shape: {O_rtl.shape}")
    print(f"  Range: [{O_rtl.min()}, {O_rtl.max()}]")

    # Compute errors
    errors = compute_errors(O_golden, O_rtl)

    print(f"\n{'='*60}")
    print("Error Metrics")
    print(f"{'='*60}")
    print(f"  Mean absolute error: {errors['mean_abs_error']:.6f}")
    print(f"  Max absolute error:  {errors['max_abs_error']:.6f}")
    print(f"  RMS error:           {errors['rms_error']:.6f}")
    print(f"  Total elements:      {errors['num_elements']}")
    print(f"  Elements with error > 0.01: {errors['num_errors_gt_001']}")
    print(f"  Elements with error > 0.03: {errors['num_errors_gt_003']}")
    print(f"  Elements with error > 0.10: {errors['num_errors_gt_010']}")

    # Check thresholds
    print(f"\n{'='*60}")
    print("Verification Result")
    print(f"{'='*60}")

    pass_mean = errors['mean_abs_error'] <= 0.03
    pass_max = errors['max_abs_error'] <= 0.10

    print(f"  mean_abs_error <= 0.03: {'PASS' if pass_mean else 'FAIL'} "
          f"({errors['mean_abs_error']:.6f})")
    print(f"  max_abs_error  <= 0.10: {'PASS' if pass_max else 'FAIL'} "
          f"({errors['max_abs_error']:.6f})")

    if pass_mean and pass_max:
        print(f"\n  Overall: PASS")
        return 0
    else:
        print(f"\n  Overall: FAIL")
        return 1


if __name__ == "__main__":
    sys.exit(main())
