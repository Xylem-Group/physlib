/-
  AxiomGate.lean — full-environment axiom allowlist gate for physlib.

  Walks EVERY non-internal declaration whose defining module is a first-party
  project module (module name begins with `Physlib` or `QuantumInfo`), runs
  `collectAxioms` on each, and QUARANTINES any declaration whose transitive
  axiom set is not a subset of the allowlist:

      { propext, Classical.choice, Quot.sound }

  This catches, by construction (anything not on the allowlist fails):
    * `sorryAx`            — an unfinished proof,
    * `Lean.ofReduceBool`  — the `native_decide` kernel-trust widener,
    * any hand-declared `axiom` a search introduced and then USED.

  It is deliberately NOT a hand-maintained list of theorem names: it enumerates
  the whole first-party environment, so a search cannot hide a tainted lemma by
  simply not adding its name to a gate array.

  Output contract (machine-parseable, stable):
    AXIOM-GATE modules-scanned=<n> decls-scanned=<n> clean=<n> quarantined=<n>
    QUARANTINE <fully.qualified.name> :: [<axiom>, ...]      (one per tainted decl)
    AXIOM-GATE-VERDICT PASS        (exit-intent: 0)
    AXIOM-GATE-VERDICT FAIL        (exit-intent: 1)

  The Lean process always exits 0 (a `#eval` cannot set the OS exit code cleanly
  across toolchains); the bash driver (`run-axiom-gate.sh`) decides pass/fail from
  the `AXIOM-GATE-VERDICT` line. That keeps the trust boundary in ONE place.
-/
import Physlib
import QuantumInfo

open Lean

/-- Allowlisted axioms. Everything else is a trust-widener and fails the gate. -/
private def allowedAxioms : List Name :=
  [`propext, `Classical.choice, `Quot.sound]

/-- First-party module test: the declaration was authored in this project. -/
private def isFirstPartyModule (m : Name) : Bool :=
  m == `Physlib || (`Physlib).isPrefixOf m ||
  m == `QuantumInfo || (`QuantumInfo).isPrefixOf m

#eval show CoreM Unit from do
  let env ← getEnv
  let mut declsScanned := 0
  let mut clean := 0
  let mut quarantined := 0
  let mut modulesSeen : Std.HashSet Name := {}
  let mut lines : Array String := #[]
  for (name, info) in env.constants.map₁.toList do
    if name.isInternal then continue
    -- only real proof-carrying declarations (theorems, defs, opaque, axioms)
    let relevant :=
      match info with
      | .thmInfo _ | .defnInfo _ | .opaqueInfo _ | .axiomInfo _ => true
      | _ => false
    if !relevant then continue
    match env.getModuleIdxFor? name with
    | none => pure ()   -- decl with no home module (rare); skip
    | some idx =>
      let modName := env.header.moduleNames[idx.toNat]!
      if !isFirstPartyModule modName then continue
      modulesSeen := modulesSeen.insert modName
      declsScanned := declsScanned + 1
      let axs ← collectAxioms name
      let bad := axs.filter (fun a => !(allowedAxioms.contains a))
      if bad.isEmpty then
        clean := clean + 1
      else
        quarantined := quarantined + 1
        lines := lines.push s!"QUARANTINE {name} :: {bad.toList}"
  IO.println s!"AXIOM-GATE modules-scanned={modulesSeen.size} decls-scanned={declsScanned} clean={clean} quarantined={quarantined}"
  for l in lines do IO.println l
  if quarantined == 0 && declsScanned > 0 then
    IO.println "AXIOM-GATE-VERDICT PASS"
  else if declsScanned == 0 then
    -- an empty scan is itself suspicious (import broke / aggregator gutted): fail closed
    IO.println "AXIOM-GATE-VERDICT FAIL (no first-party declarations scanned — fail-closed)"
  else
    IO.println "AXIOM-GATE-VERDICT FAIL"
