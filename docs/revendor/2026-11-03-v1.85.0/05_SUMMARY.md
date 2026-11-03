# Summary

- **Tag:** none -> v1.85.0 (`fd57b83`), the first vendoring. Kit none -> 50. Per-major minors in
  `01_DELTA.md`. No span bundle, no base correction.
- **For free:** nothing yet. At this commit nothing loads the library: the legacy TOC is untouched
  and no seam file exists.
- **Blockers:** none. There is no earlier contract to have moved.
- **Icons:** 20 declared (Open Iconic plus Phosphor `lightning`); both icon-set license files ship,
  and the README credits both sets once P10 restyles it.
- **Horizon:** the 16 leased majors are adopted seam by seam through P3 (C5 Core, Env, Media; C6
  Compat; C7 Bus; C8 Skin; C9 Pool, Item, Widgets; C10 Lifecycle, Perf; C11 DebugLog; C12 Schema,
  Slash, Options; C13 Launcher), with the kit's suites live from C5. P4.31 re-checks the icon
  declaration against every `NS.Icon(` call and re-prunes if it moved. **Declined:** Glow, Toast,
  Charts and Sim (design H18 and §1.1).
- **Gate at the copy:** the legacy `./tests/run-all.sh`, green. This is the last legacy-gated
  commit.
