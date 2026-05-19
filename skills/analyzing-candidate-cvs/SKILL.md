---
name: analyzing-candidate-cvs
description: >-
  Analyzes candidate CVs/resumes against one or more job offers. Use when the
  user asks to screen resumes, compare candidates, prepare technical interviews,
  build hiring shortlists, analyze CV PDFs/DOCX files, or produce candidate
  evaluation matrices and recommendations.
---

# Analyzing Candidate CVs

Use this skill to analyze a hiring campaign from job offer(s) and candidate resumes. Produce structured, evidence-based French or English outputs depending on the user's preference.

## Core principles

- Start from the job offer: extract criteria before reading CVs.
- Separate candidates by job offer/campaign when multiple roles exist.
- Treat CV evidence carefully: distinguish **attested**, **partial/indirect**, **absent**, and **not evaluable from CV**.
- Do not invent experience. If a skill, location, seniority, or availability is not in the CV, mark it as non-evaluable or a point to confirm.
- Avoid automatic elimination unless the user defines eliminatory criteria.
- If candidates are already preselected for interview, optimize the output for **interview preparation**, not just screening.
- Include role-specific interview questions to validate gaps and critical assumptions.

## Recommended directory structure

Prefer one directory per job offer/campaign:

```text
cv-analysis/
├── role-a/
│   ├── job-offer.pdf|docx|txt
│   └── candidates/
│       ├── candidate-1.pdf|docx
│       └── candidate-2.pdf|docx
└── role-b/
    ├── job-offer.pdf|docx|txt
    └── candidates/
        └── ...
```

Create outputs under:

```text
cv-analysis/_extracted_text/
cv-analysis/_reports/
```

## Workflow

1. **Inventory files**
   - List job offers and candidate files.
   - Flag duplicates or ambiguous assignments.
   - Ask the user how to handle duplicates, mixed roles, missing offers, or unclear CV ownership.

2. **Extract text**
   - Use `scripts/extract_documents.py` when possible.
   - For scanned PDFs or poor extraction, use OCR tooling if available and clearly flag extraction uncertainty.

3. **Build the evaluation grid from the job offer**
   - Extract responsibilities, required skills, desired skills, experience, education, domain constraints, soft skills, and practical constraints.
   - Propose weights before scoring unless the user already approved a grid.
   - Suggested default weighting:
     - Technical skills: 35%
     - Practical know-how / delivery experience: 25%
     - Soft skills / collaboration: 15%
     - Background / seniority / domain fit: 25%

4. **Validate assumptions with the user**
   - Confirm weights, eliminatory criteria, language, desired depth, and whether the output is for triage or interview preparation.
   - Add non-scored practical constraints such as location/onsite availability when relevant.

5. **Analyze candidates**
   - Use only one copy of duplicate CVs.
   - Score each candidate against the approved grid.
   - For every conclusion, ground it in CV evidence.
   - Highlight transferable strengths separately from direct role fit.

6. **Produce reports**
   - Create one detailed report per role/campaign.
   - Create an executive synthesis if there are multiple roles or many candidates.
   - Include matrices, candidate fiches, recommendations, ranking/prioritization, and interview questions.

7. **Quality check**
   - Re-read the ranking for consistency with the evidence.
   - Check that “not mentioned” is not treated as “false”.
   - Check that strong candidates outside the exact role are identified as such, not dismissed generically.

## Evaluation markers

Use a compact legend in matrices:

| Marker | Meaning |
|---|---|
| ✅ | Explicitly attested in CV |
| ⚠️ or ⚡ | Partial, indirect, limited, or unclear evidence |
| ❌ | Not present in CV |
| ❓ | Not evaluable from CV / confirm in interview |

## Output structure

For each role, include:

1. Campaign context and files analyzed
2. Evaluation grid and weights
3. Comparative matrix
4. Candidate ranking / prioritization
5. Detailed candidate fiches:
   - Profile summary
   - Evidence by criterion
   - Strengths
   - Gaps / points to clarify
   - Practical constraints visible in CV
   - Recommendation: Favorable / À approfondir / Défavorable (or equivalent in requested language)
   - Personalized interview questions
6. Cross-candidate observations
7. Methodological caveats

For a reusable report skeleton, see `references/report-template.md`.

## Tooling notes

- Use Python libraries such as `pdfplumber` for PDFs and `python-docx` for DOCX.
- If installing dependencies, prefer a project virtual environment when available; otherwise explain the choice.
- CV data is personal data: avoid copying reports outside the working directory unless requested, and do not commit CVs or reports to a repository without explicit user approval.
