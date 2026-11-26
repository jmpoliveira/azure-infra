# ADR 0002: Model deployments are Global Standard for now; Data Zone Standard (EU) is the target

Status: accepted

## Context

Adopting the portal-made resources (ADR 0001) showed that all four model deployments on
`jorgepratesoliveira-259-resource` (Sweden Central) use the **GlobalStandard** SKU:
`gpt-6-luna`, `text-embedding-3-small`, `gpt-5.2` and `gpt-5`. The account is in the EU, but with
Global Standard a request may be processed in any Azure region where the model is available. The
intent recorded so far (agent ADR 0007) was **DataZoneStandard** in the European data zone, which
keeps processing in the EU. On 2026-11-22 the subscription had 0 TPM of `gpt-6-luna` quota in
every deployment type; quota was then granted, and the deployment was made as Global Standard.

The data is synthetic today (the Tessera help-centre corpus and mock customers), so nothing
personal leaves the EU. With real customer data, processing location becomes a GDPR and contract
question, and an architect has to be able to state it precisely.

## Decision

1. **Adopt the deployments as they are** (GlobalStandard, same capacities), so the first
   `what-if` changes nothing and the gap is visible in code instead of hidden in the portal.
2. **Target: DataZoneStandard** for every deployment that will see real data, starting with
   `gpt-6-luna` and `text-embedding-3-small`.
3. **Migrate side by side, never in place.** A deployment's SKU type is part of how its quota is
   allocated; the safe path is a new deployment next to the old one:
   1. request Data Zone Standard quota for the model in Sweden Central (Foundry portal > Quota);
   2. add a deployment such as `gpt-6-luna-eu` (DataZoneStandard) to `env/dev.bicepparam`;
      `what-if`, deploy;
   3. point the client at it (`FOUNDRY_MODEL=gpt-6-luna-eu` in ai-agent-service) and re-run the
      E5 eval, since a different deployment type may behave or perform differently;
   4. remove the Global Standard deployment from the parameters and delete it.
4. `gpt-5.2` and `gpt-5` are used by no repository. They stay as found for now; whether to keep
   them is a separate change (they hold quota, and cost nothing while idle).

## Consequences

- Until the migration, documentation must not claim EU processing.
- The agent's ADR 0007 and its E5 notes say "Data Zone Standard (EUR)"; they need a correction.
- Model versions are pinned in the parameters, but `versionUpgradeOption` is
  `OnceNewDefaultVersionAvailable` (the portal default), so Azure may move a deployment to a new
  model version and `what-if` will then report drift on `version`. A version change can change
  eval results; `NoAutoUpgrade` is the stricter choice once the baselines matter more.
