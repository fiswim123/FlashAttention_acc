#!/usr/bin/env python3
"""
FlashAttention Golden Model (FP32)
Used for RTL verification - generates expected outputs and compares with RTL results.

Mathematical basis:
  O_i = sum_j softmax(Q_i * K_j^T / sqrt(d) + M_ij) * V_j

FlashAttention online algorithm:
  For each query row i:
    m = -inf, l = 0, acc = 0
    For each K/V tile k:
      score = Q[i] @ K_tile^T / sqrt(d)
      m_new = max(m, max(score))
      l_new = exp(m - m_new) * l + sum(exp(score - m_new))
      acc_new = exp(m - m_new) * acc + exp(score - m_new) @ V_tile
      m, l, acc = m_new, l_new, acc_new
    O[i] = acc / l
"""

import numpy as np
from typing import Tuple, Optional


def float_to_q88(x: np.ndarray) -> np.ndarray:
    """Convert float to Q8.8 fixed-point (16-bit signed)."""
    # Q8.8: 8 integer bits, 8 fractional bits
    # Range: [-128, +127.996]
    scaled = np.clip(x * 256.0, -32768, 32767)
    return np.round(scaled).astype(np.int16)


def q88_to_float(x: np.ndarray) -> np.ndarray:
    """Convert Q8.8 fixed-point to float."""
    return x.astype(np.float64) / 256.0


def float_to_q88_scalar(x: float) -> int:
    """Convert single float to Q8.8 integer."""
    scaled = np.clip(x * 256.0, -32768, 32767)
    return int(np.round(scaled))


def q88_to_float_scalar(x: int) -> float:
    """Convert single Q8.8 integer to float."""
    return float(x) / 256.0


def generate_random_inputs(S: int = 256, d: int = 64, seed: int = 42) -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
    """
    Generate random Q, K, V matrices in Q8.8 format.

    Args:
        S: Sequence length
        d: Head dimension
        seed: Random seed for reproducibility

    Returns:
        Q, K, V as int16 arrays in Q8.8 format, shape [S, d]
    """
    rng = np.random.RandomState(seed)

    # Generate random values in range [-2, 2] for Q8.8 compatibility
    Q_float = rng.uniform(-2.0, 2.0, (S, d)).astype(np.float64)
    K_float = rng.uniform(-2.0, 2.0, (S, d)).astype(np.float64)
    V_float = rng.uniform(-2.0, 2.0, (S, d)).astype(np.float64)

    # Convert to Q8.8
    Q_q88 = float_to_q88(Q_float)
    K_q88 = float_to_q88(K_float)
    V_q88 = float_to_q88(V_float)

    return Q_q88, K_q88, V_q88


def flash_attention_golden(
    Q: np.ndarray,
    K: np.ndarray,
    V: np.ndarray,
    causal: bool = True,
    S: int = 256,
    d: int = 64
) -> np.ndarray:
    """
    FP32 golden model for FlashAttention.

    Args:
        Q, K, V: Input matrices in Q8.8 format (int16), shape [S, d]
        causal: Whether to apply causal mask
        S: Sequence length
        d: Head dimension

    Returns:
        O: Output matrix in Q8.8 format (int16), shape [S, d]
    """
    # Convert Q8.8 to float for computation
    Q_f = q88_to_float(Q)
    K_f = q88_to_float(K)
    V_f = q88_to_float(V)

    scale = 1.0 / np.sqrt(d)

    O_float = np.zeros((S, d), dtype=np.float64)

    for i in range(S):
        # Initialize online softmax state
        m_i = -np.inf  # running max
        l_i = 0.0      # running sum of exp
        acc_i = np.zeros(d, dtype=np.float64)  # running weighted sum

        for j in range(S):
            # Apply causal mask
            if causal and j > i:
                continue

            # Compute score: Q[i] @ K[j] / sqrt(d)
            score = np.dot(Q_f[i], K_f[j]) * scale

            # Online softmax update
            m_new = max(m_i, score)

            # Rescale previous accumulator
            if m_i == -np.inf:
                # First valid element
                l_new = np.exp(score - m_new)
                acc_new = np.exp(score - m_new) * V_f[j]
            else:
                correction = np.exp(m_i - m_new)
                l_new = correction * l_i + np.exp(score - m_new)
                acc_new = correction * acc_i + np.exp(score - m_new) * V_f[j]

            m_i = m_new
            l_i = l_new
            acc_i = acc_new

        # Normalize
        if l_i > 0:
            O_float[i] = acc_i / l_i
        else:
            O_float[i] = np.zeros(d)

    # Convert back to Q8.8
    O_q88 = float_to_q88(O_float)

    return O_q88


def flash_attention_tiled(
    Q: np.ndarray,
    K: np.ndarray,
    V: np.ndarray,
    causal: bool = True,
    S: int = 256,
    d: int = 64,
    Bc: int = 16
) -> np.ndarray:
    """
    Tiled version of FlashAttention golden model (matches hardware implementation).

    Args:
        Q, K, V: Input matrices in Q8.8 format (int16), shape [S, d]
        causal: Whether to apply causal mask
        S: Sequence length
        d: Head dimension
        Bc: Tile size for K/V

    Returns:
        O: Output matrix in Q8.8 format (int16), shape [S, d]
    """
    # Convert Q8.8 to float for computation
    Q_f = q88_to_float(Q)
    K_f = q88_to_float(K)
    V_f = q88_to_float(V)

    scale = 1.0 / np.sqrt(d)

    O_float = np.zeros((S, d), dtype=np.float64)

    for i in range(S):
        # Initialize online softmax state
        m_i = -np.inf
        l_i = 0.0
        acc_i = np.zeros(d, dtype=np.float64)

        # Process K/V in tiles
        for tile_start in range(0, S, Bc):
            tile_end = min(tile_start + Bc, S)

            # Apply causal mask at tile level
            if causal and tile_start > i:
                continue  # Skip entire tile

            for j in range(tile_start, tile_end):
                # Apply causal mask at element level
                if causal and j > i:
                    continue

                # Compute score
                score = np.dot(Q_f[i], K_f[j]) * scale

                # Online softmax update
                m_new = max(m_i, score)

                if m_i == -np.inf:
                    l_new = np.exp(score - m_new)
                    acc_new = np.exp(score - m_new) * V_f[j]
                else:
                    correction = np.exp(m_i - m_new)
                    l_new = correction * l_i + np.exp(score - m_new)
                    acc_new = correction * acc_i + np.exp(score - m_new) * V_f[j]

                m_i = m_new
                l_i = l_new
                acc_i = acc_new

        # Normalize
        if l_i > 0:
            O_float[i] = acc_i / l_i
        else:
            O_float[i] = np.zeros(d)

    # Convert back to Q8.8
    O_q88 = float_to_q88(O_float)

    return O_q88


def compute_errors(O_golden: np.ndarray, O_rtl: np.ndarray) -> dict:
    """
    Compute error metrics between golden and RTL outputs.

    Args:
        O_golden: Golden output in Q8.8 format (int16)
        O_rtl: RTL output in Q8.8 format (int16)

    Returns:
        Dictionary with error metrics
    """
    # Convert to float for error computation
    O_golden_f = q88_to_float(O_golden)
    O_rtl_f = q88_to_float(O_rtl)

    # Compute absolute errors
    abs_errors = np.abs(O_golden_f - O_rtl_f)

    return {
        'mean_abs_error': float(np.mean(abs_errors)),
        'max_abs_error': float(np.max(abs_errors)),
        'rms_error': float(np.sqrt(np.mean(abs_errors ** 2))),
        'num_elements': int(abs_errors.size),
        'num_errors_gt_001': int(np.sum(abs_errors > 0.01)),
        'num_errors_gt_003': int(np.sum(abs_errors > 0.03)),
        'num_errors_gt_010': int(np.sum(abs_errors > 0.10)),
    }


def generate_test_vectors(
    S: int = 256,
    d: int = 64,
    num_tests: int = 1,
    seed: int = 42
) -> list:
    """
    Generate test vectors with expected outputs.

    Args:
        S: Sequence length
        d: Head dimension
        num_tests: Number of test cases
        seed: Base random seed

    Returns:
        List of test case dictionaries
    """
    test_cases = []

    for test_id in range(num_tests):
        current_seed = seed + test_id

        # Generate random inputs
        Q, K, V = generate_random_inputs(S, d, current_seed)

        # Compute golden output
        O_golden = flash_attention_tiled(Q, K, V, causal=True, S=S, d=d)

        test_cases.append({
            'test_id': test_id,
            'seed': current_seed,
            'S': S,
            'd': d,
            'Q': Q,
            'K': K,
            'V': V,
            'O_golden': O_golden,
        })

    return test_cases


def save_test_vectors(test_cases: list, filename: str):
    """Save test vectors to file for RTL simulation."""
    with open(filename, 'w') as f:
        for tc in test_cases:
            f.write(f"TEST_ID: {tc['test_id']}\n")
            f.write(f"SEED: {tc['seed']}\n")
            f.write(f"S: {tc['S']}\n")
            f.write(f"D: {tc['d']}\n")

            # Write Q
            f.write("Q:\n")
            for row in tc['Q']:
                f.write(' '.join(str(x) for x in row) + '\n')

            # Write K
            f.write("K:\n")
            for row in tc['K']:
                f.write(' '.join(str(x) for x in row) + '\n')

            # Write V
            f.write("V:\n")
            for row in tc['V']:
                f.write(' '.join(str(x) for x in row) + '\n')

            # Write O_golden
            f.write("O_GOLDEN:\n")
            for row in tc['O_golden']:
                f.write(' '.join(str(x) for x in row) + '\n')

            f.write("---\n")


if __name__ == "__main__":
    # Generate test vectors
    print("Generating test vectors...")
    test_cases = generate_test_vectors(S=256, d=64, num_tests=3, seed=42)

    # Save to file
    save_test_vectors(test_cases, "verify/test_vectors.txt")
    print(f"Saved {len(test_cases)} test cases to verify/test_vectors.txt")

    # Print summary
    for tc in test_cases:
        print(f"\nTest {tc['test_id']} (seed={tc['seed']}):")
        print(f"  Q range: [{tc['Q'].min()}, {tc['Q'].max()}]")
        print(f"  K range: [{tc['K'].min()}, {tc['K'].max()}]")
        print(f"  V range: [{tc['V'].min()}, {tc['V'].max()}]")
        print(f"  O_golden range: [{tc['O_golden'].min()}, {tc['O_golden'].max()}]")
