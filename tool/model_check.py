#!/usr/bin/env python3
"""A tiny model-based testing harness (language-neutral pattern; port it to your test framework).

You provide: a generator of random events, a reference model, the system under test (or an adapter over the
real code), and invariants. The harness runs seeded sequences, checks every invariant after every event,
and on failure shrinks the sequence and prints it as a regression case.
"""
import random


def run(seq, make_model, make_system, invariants):
    model, system = make_model(), make_system()
    for i, ev in enumerate(seq):
        model.apply(ev)
        system.apply(ev)
        for inv in invariants:
            ok, why = inv(model, system)
            if not ok:
                return i, inv.__name__, why
    return None


def shrink(seq, fails):
    """Remove chunks, then single events, while the sequence still fails."""
    n = 2
    while len(seq) >= 2:
        chunk = max(1, len(seq) // n)
        for start in range(0, len(seq), chunk):
            cand = seq[:start] + seq[start + chunk:]
            if fails(cand):
                seq, n = cand, max(n - 1, 2)
                break
        else:
            if chunk == 1:
                break
            n = min(n * 2, len(seq))
    return seq


def check(gen_event, make_model, make_system, invariants, seeds=range(200), length=200):
    for seed in seeds:
        rng = random.Random(seed)
        seq = [gen_event(rng) for _ in range(length)]
        res = run(seq, make_model, make_system, invariants)
        if res:
            small = shrink(seq, lambda s: run(s, make_model, make_system, invariants) is not None)
            i, name, why = run(small, make_model, make_system, invariants)
            raise AssertionError(f'seed {seed}: {name} broke at event {i}: {why}\n'
                                 f'keep as a named case:\n  {small}')


if __name__ == '__main__':
    # Example: a counter that must never exceed a cap of 3 offers per install.
    class Model:
        def __init__(self): self.shows = 0
        def apply(self, ev):
            if ev == 'aha' and self.shows < 3: self.shows += 1
    class Buggy(Model):
        def apply(self, ev):
            if ev == 'aha': self.shows += 1           # forgets the cap
            if ev == 'reinstall': self.shows = 0
    def cap(model, system): return system.shows <= 3, f'shows={system.shows}'
    gen = lambda rng: rng.choice(['aha', 'clock', 'reinstall'])
    check(gen, Model, Model, [cap])
    print('model vs model: ok')
    try:
        check(gen, Model, Buggy, [cap])
    except AssertionError as e:
        print('buggy system caught:', str(e).splitlines()[0])
        print(str(e).splitlines()[-1])
