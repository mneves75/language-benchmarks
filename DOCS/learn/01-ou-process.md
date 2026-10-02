# Chapter 1: The Ornstein–Uhlenbeck process

Imagine a particle attached to a spring and pushed by random disturbances.
The spring pulls toward its resting position; noise changes the path.

The OU stochastic differential equation is

```text
dX(t) = theta * (mu - X(t)) * dt + sigma * dW(t)
```

Here `theta` is mean-reversion strength, `mu` the mean, `sigma` the noise
scale, and `W(t)` Brownian motion. Brownian increments over length `dt`
have variance `dt`. The model appears in Uhlenbeck and Ornstein's
[On the Theory of the Brownian Motion](https://doi.org/10.1103/PhysRev.36.823).
The analogy does not make every fluctuating real-world series an OU process.

## From an equation to a loop

Euler–Maruyama approximates the process with discrete updates:

```text
X[i] = X[i-1] + theta * (mu - X[i-1]) * dt
                    + sigma * sqrt(dt) * Z[i-1]
Z[i-1] ~ standard normal
```

The benchmark precomputes:

```text
a = 1 - theta * dt
b = theta * mu * dt
diff = sigma * sqrt(dt)
gn[i] = diff * Z[i]
X[i] = (a * X[i-1] + b) + gn[i-1]
```

This moves coefficient work out of the loop. Preserve operation order when
porting: floating-point arithmetic is not associative.

## The actual time grid

Fixed parameters are `theta=1`, `mu=0`, `sigma=0.1`, and `X[0]=0`.
The nominal interval is `T=1`. The benchmark defines `dt=T/n`, stores
`n` path values, and performs `n-1` updates.

For `n=4`, stored times are `0, 0.25, 0.5, 0.75`.
The final time is `(n-1)/n`. Changing the denominator to `n-1` changes
the benchmark. For plots, use times `i/n` for `i in range(n)`.

This Python example accepts already scaled noise. It explains the recurrence;
it is not a seventh benchmark implementation:

```python
def path(noise):
    n = len(noise) + 1
    a = 1.0 - 1.0 / n
    b = 0.0
    x = 0.0
    values = [x]
    for kick in noise:
        x = (a * x + b) + kick
        values.append(x)
    return values

values = path([0.01, -0.02, 0.03])
# Approximately [0.0, 0.01, -0.0125, 0.020625].
```

## Approximation and limits

Euler remains an approximation with correctly sampled noise. OU also has an
exact Gaussian transition, but using it changes the workload and seeded results.
Compare it in a separately named experiment.

For valid `n>=2`, `a=1-1/n` satisfies `0<a<1`. Without noise the
recurrence decays toward zero. Noise can push a path far from the mean; there
is no hard bound. One path's average need not equal `mu`. Distribution checks
require ensembles, not a plausible-looking single path.

## Practice

- Trace `n=2`: one update and final time `1/2`.
- Explain why zero noise gives an identically zero path for these parameters.
- Predict how changing `sigma` affects noise variance in a separate experiment.
- Derive `E[X[i]]=a*E[X[i-1]]+b`.

Previous: [Introduction](00-introduction.md).
Next: [Random numbers](02-random-numbers.md).
