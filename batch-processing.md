# Bounded batch processing

Calendar calculations are pure values and need no process of their own. When an application has many independent exports, `Batch.run/3` wraps `Task.async_stream/3` with a positive concurrency limit and timeout.

```elixir
Batch.run(months, &render_month/1, max_concurrency: 4, timeout: 5_000, ordered: true)
```

Ordered mode preserves input order. Unordered mode can return results as tasks finish. A timeout or task exit becomes an error tuple so callers can decide whether to retry or report a failed export. Do not feed an unbounded external stream without applying your own input and output bounds.

Concurrency is useful when work waits on I/O or is expensive enough to amortize scheduling. A small SVG render may be faster sequentially. Benchmark representative workloads on the deployment hardware before increasing concurrency. The core package does not claim benchmark numbers.

Phoenix applications can run bounded work from supervised tasks and return generated values to a controller or LiveView. Validate user-selected date spans and concurrency options at the web boundary.
