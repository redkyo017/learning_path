# WSO2 Mastery — Progress Tracker

**Spec:** `docs/superpowers/specs/2026-08-31-wso2-mastery-design.md`
**Total:** 4 phases × 15 days = 60 days, 3h/day (~180h)

---

## Current Status

| Phase | Days | Title | Status |
|---|---|---|---|
| Phase 1 | 1–15 | Identity Core (OAuth2/OIDC + Key Manager) | ✅ COMPLETE — all content + labs authored |
| Phase 2 | 16–30 | API Gateway (Mediation + JWT + Throttle) | 🔄 Days 16–18 done, Tasks 2–5 remain |
| Phase 3 | 31–45 | Control Plane + Event Sync | ⬜ Not started |
| Phase 4 | 46–60 | Production Mastery (Debug + Extend + Deploy) | ⬜ Not started |

**Active phase:** Phase 2 — ready to plan (Days 16–30: API Gateway).

---

## Session Log

| Date | Session goal | Result |
|---|---|---|
| 2026-08-31 | Brainstorm + spec | Spec written. 4-phase breakdown complete. |
| 2026-08-31 | Phase 1 plan | Plan written: 5 tasks, 15 days, scaffold + content + Go labs. |
| 2026-08-31 | Phase 1 complete | All 5 tasks done. 15 day files + 15 lab dirs (Go servers + Docker + playbook). |
| 2026-08-31 | Phase 2 Days 16-18 | Synapse mediation + Go reverse proxy + handler chain + graceful shutdown. |

---

## Next Session Instructions

Paste this into Claude Code to continue:

```
Continue WSO2 mastery learning path. Read PROGRESS.md first, then read the spec at
docs/superpowers/specs/2026-08-31-wso2-mastery-design.md.

Next step: continue Phase 2 content authoring — Tasks 2–5 (Days 19–30).
SDD ledger: .superpowers/sdd/2026-08-31-wso2-phase2-plan/progress.md (Tasks 0+1 complete).
Phase 2 plan: docs/superpowers/plans/2026-08-31-wso2-phase2-plan.md
Use local skill.md + subagent-driven-development. Switch to Haiku 4.5 to save budget.
```

---

## Phase Plans

| Phase | Plan file | Status |
|---|---|---|
| Phase 1 | `docs/superpowers/plans/2026-08-31-wso2-phase1-plan.md` | ✅ Written |
| Phase 2 | `docs/superpowers/plans/2026-08-31-wso2-phase2-plan.md` | ✅ Written |
| Phase 3 | `docs/superpowers/plans/YYYY-MM-DD-wso2-phase3-plan.md` | ⬜ Not written |
| Phase 4 | `docs/superpowers/plans/YYYY-MM-DD-wso2-phase4-plan.md` | ⬜ Not written |

---

## WSO2 Source References

| Component | Local path |
|---|---|
| WSO2 IS 7.3 | `/Users/hunghan/Downloads/wso2is-7.3.0` |
| WSO2 APIM Universal GW 4.7 | `/Users/hunghan/Downloads/wso2am-universal-gw-4.7.0` |
| WSO2 APIM Control Plane 4.7 | `/Users/hunghan/Downloads/wso2am-acp-4.7.0` |

---

## Learner Profile (for future sessions)

- Strong Go engineer; minimal Java/Spring experience
- Company runs distributed WSO2 on AWS ECS Fargate: Control Plane + Universal GW + Traffic Manager + IS (3rd-party key manager) as separate services
- Goal: architect depth — debug production incidents, make deployment decisions, write custom extensions
- 3h/day, local Docker (Phases 1-2) + AWS account (Phases 3-4)
