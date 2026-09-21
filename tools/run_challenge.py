#!/usr/bin/env python3
"""Run a locally-built LeetGPU CUDA solution against upstream functional tests."""

from __future__ import annotations

import argparse
import copy
import ctypes
import importlib.util
import sys
from pathlib import Path
from typing import Any


def _load_challenge(challenge_dir: Path):
    challenges_root = challenge_dir.parents[1]
    sys.path.insert(0, str(challenges_root))
    spec = importlib.util.spec_from_file_location("leetgpu_challenge", challenge_dir / "challenge.py")
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {challenge_dir / 'challenge.py'}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.Challenge(device="cuda")


def _clone_case(case: dict[str, Any], torch) -> dict[str, Any]:
    cloned: dict[str, Any] = {}
    for key, value in case.items():
        if isinstance(value, torch.Tensor):
            cloned[key] = value.clone()
        else:
            cloned[key] = copy.deepcopy(value)
    return cloned


def _ctypes_arg(value: Any, ctype: Any, torch):
    if isinstance(value, torch.Tensor):
        # challenge.py already specifies the pointee type; preserve that exact ABI.
        return ctypes.cast(ctypes.c_void_p(value.data_ptr()), ctype)
    if isinstance(value, ctypes._SimpleCData):
        return value
    return ctype(value)


def _compare(name: str, actual, expected, atol: float, rtol: float, torch) -> tuple[bool, str]:
    if not isinstance(actual, torch.Tensor) or not isinstance(expected, torch.Tensor):
        ok = actual == expected
        return ok, "" if ok else f"{name}: {actual!r} != {expected!r}"

    if actual.shape != expected.shape:
        return False, f"{name}: shape {tuple(actual.shape)} != {tuple(expected.shape)}"

    if actual.dtype.is_floating_point or actual.dtype.is_complex:
        ok = torch.allclose(actual, expected, atol=atol, rtol=rtol, equal_nan=True)
        if ok:
            return True, ""
        wide_dtype = torch.complex128 if actual.dtype.is_complex else torch.float64
        a = actual.to(wide_dtype)
        e = expected.to(wide_dtype)
        max_abs = (a - e).abs().max().item() if actual.numel() else 0.0
        denom = e.abs().clamp_min(1e-30)
        max_rel = ((a - e).abs() / denom).max().item() if actual.numel() else 0.0
        return False, f"{name}: max_abs={max_abs:.6g}, max_rel={max_rel:.6g}"

    ok = torch.equal(actual, expected)
    return ok, "" if ok else f"{name}: integer/bool tensor mismatch"


def run(challenge_dir: Path, library: Path, include_example: bool) -> int:
    try:
        import torch
    except ImportError as exc:
        print("error: local correctness tests require PyTorch with CUDA support", file=sys.stderr)
        print("       compilation/clangd still work without PyTorch", file=sys.stderr)
        raise SystemExit(2) from exc

    if not torch.cuda.is_available():
        print("error: torch.cuda.is_available() is false; a CUDA-capable PyTorch environment is required", file=sys.stderr)
        return 2

    challenge = _load_challenge(challenge_dir)
    signature = challenge.get_solve_signature()

    lib = ctypes.CDLL(str(library))
    solve = lib.solve
    solve.restype = None
    solve.argtypes = [entry[0] for entry in signature.values()]

    tests = list(challenge.generate_functional_test())
    if include_example:
        tests.insert(0, challenge.generate_example_test())

    passed = 0
    for index, raw_case in enumerate(tests, start=1):
        actual_case = _clone_case(raw_case, torch)
        expected_case = _clone_case(raw_case, torch)

        # Compute the oracle before the student's kernel mutates any inout/output tensors.
        challenge.reference_impl(**expected_case)
        # Make the oracle complete before invoking a separately-built CUDA runtime library.
        torch.cuda.synchronize()

        args = []
        for name, (ctype, _direction) in signature.items():
            if name not in actual_case:
                raise KeyError(f"{challenge.name}: missing argument {name!r} in generated test")
            args.append(_ctypes_arg(actual_case[name], ctype, torch))

        solve(*args)
        torch.cuda.synchronize()

        failures: list[str] = []
        for name, (_ctype, direction) in signature.items():
            if direction not in {"out", "inout"}:
                continue
            ok, detail = _compare(
                name,
                actual_case[name],
                expected_case[name],
                challenge.atol,
                challenge.rtol,
                torch,
            )
            if not ok:
                failures.append(detail)

        if failures:
            print(f"[{index:02d}/{len(tests):02d}] FAIL")
            for failure in failures:
                print(f"  {failure}")
            return 1

        passed += 1
        print(f"[{index:02d}/{len(tests):02d}] PASS")

    print(f"\n{challenge.name}: {passed}/{len(tests)} passed")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--challenge-dir", type=Path, required=True)
    parser.add_argument("--library", type=Path, required=True)
    parser.add_argument("--no-example", action="store_true")
    args = parser.parse_args()
    return run(args.challenge_dir.resolve(), args.library.resolve(), not args.no_example)


if __name__ == "__main__":
    raise SystemExit(main())
