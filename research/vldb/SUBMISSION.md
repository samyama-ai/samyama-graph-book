# VLDB 2026 Submission Instructions

**Target**: PVLDB Volume 19, Research Track
**Deadline**: May 1, 2026 (5:00 PM Pacific Time)
**Submission URL**: https://cmt3.research.microsoft.com/PVLDBv19
**Formatting guide**: https://www.vldb.org/pvldb/volumes/19/formatting/

---

## Pre-Submission Checklist

### Formatting
- [ ] Uses `\documentclass[sigconf, nonacm]{acmart}` (PVLDB template)
- [ ] Title does NOT include track tag (only non-regular papers need `[Experiment, Analysis & Benchmark]`)
- [ ] Author names and affiliations on first page (single-blind review)
- [ ] Page limit: **12 pages** excluding references (references unlimited)
- [ ] Two-column format, 10pt body text
- [ ] PVLDB macros set: `\vldbvolume{19}`, `\vldbyear{2026}`
- [ ] `\vldbpagestyle{plain}` (for review version; change to `empty` for camera-ready)
- [ ] `\vldbavailabilityurl{https://github.com/samyama-ai/samyama-graph}` set
- [ ] `\balance` on last page for balanced columns
- [ ] All fonts embedded (compile with `pdflatex`, not `latex+dvips`)

### Content
- [ ] Abstract ≤ 300 words
- [ ] Paper is self-contained (reviewer should not need external links to understand contributions)
- [ ] All figures are readable in black-and-white print
- [ ] All tables have captions above, figures have captions below
- [ ] References use ACM Reference Format (`\bibliographystyle{ACM-Reference-Format}`)
- [ ] No acknowledgments section in review version (add in camera-ready only)

### Artifacts
- [ ] Code repository is public: https://github.com/samyama-ai/samyama-graph
- [ ] Benchmark reproduction instructions in repo README or docs/
- [ ] Architecture book link included: https://samyama-ai.github.io/samyama-graph-book/

---

## Compilation

```bash
cd samyama-graph-book/research/vldb/

# Full build (3 passes for references + cross-refs)
pdflatex samyama-vldb.tex
bibtex samyama-vldb
pdflatex samyama-vldb.tex
pdflatex samyama-vldb.tex

# Verify
open samyama-vldb.pdf
```

### Check PDF/A compliance (required for camera-ready, recommended for submission)
```bash
# macOS: use Acrobat or online validator
# https://www.pdf-online.com/osa/validate.aspx
```

---

## Submission Steps

### 1. Create CMT account (if needed)
- Go to https://cmt3.research.microsoft.com/PVLDBv19
- Create account or log in
- Select "Author" role

### 2. Start new submission
- Click "Create New Submission"
- Select track: **Research Track**
- Enter title: `Samyama: A Unified Graph-Vector Database with Late Materialization and Graph-Native Query Planning`

### 3. Enter metadata
- **Authors**:
  - Madhulatha Mandarapu (madhulatha@samyama.ai, VaidhyaMegha Private Limited, ORCID: 0009-0005-2837-6725)
  - Sandeep Kunkunuru (sandeep@samyama.ai, VaidhyaMegha Private Limited, ORCID: 0000-0002-8886-1846)
- **Abstract**: Copy from the paper
- **Keywords**: Graph Databases, Property Graphs, Late Materialization, Query Optimization, Columnar Storage, Vector Search, Rust, LDBC
- **Subject areas**: Database Systems, Query Processing, Storage and Indexing

### 4. Upload PDF
- Upload `samyama-vldb.pdf`
- Ensure file size < 15 MB
- Verify the PDF renders correctly in CMT preview

### 5. Availability URL
- Enter: `https://github.com/samyama-ai/samyama-graph`
- This appears in the paper footer via `\vldbavailabilityurl`

### 6. Conflicts of interest
- Declare any conflicts (co-authors, advisors, institutional colleagues at reviewer institutions)
- If none, select "No conflicts"

### 7. Submit
- Click "Submit"
- Verify confirmation email

---

## Review Process

| Stage | Timeline |
|-------|----------|
| Submission | May 1, 2026 |
| Notification | ~June 15, 2026 (6 weeks) |
| Revision (if "revise") | +6 weeks from notification |
| Camera-ready | 4 weeks after acceptance |
| Conference | August 31 – September 4, 2026 (Boston, MA) |

### Possible outcomes
- **Accept**: Publish in PVLDB Vol. 19
- **Revise**: Address reviewer comments, resubmit within 6 weeks (to next monthly deadline)
- **Reject**: May resubmit as new paper to a future deadline (must address all concerns)

---

## Camera-Ready Changes (if accepted)

- [ ] Change `\vldbpagestyle{plain}` to `\vldbpagestyle{empty}`
- [ ] Fill in `\vldbdoi`, `\vldbpages` with assigned values
- [ ] Add acknowledgments section
- [ ] Add "Received [date]; revised [date]; accepted [date]" if applicable
- [ ] Ensure PDF/A compliance
- [ ] At least one author must register for VLDB 2026 and present in person

---

## Key Links

| Resource | URL |
|----------|-----|
| VLDB 2026 | https://vldb.org/2026/ |
| PVLDB Vol 19 submission | https://cmt3.research.microsoft.com/PVLDBv19 |
| Formatting guidelines | https://www.vldb.org/pvldb/volumes/19/formatting/ |
| Template (GitHub) | https://github.com/cwida/pvldbstyle |
| Template (Overleaf) | https://www.overleaf.com/latex/templates/template-for-proceedings-of-the-vldb-endowment/krfrpvrbbvfj |
| Important dates | https://vldb.org/2026/important-dates.html |
| Call for papers | https://www.vldb.org/2026/call-for-research-track.html |

---

## Files

```
samyama-graph-book/research/vldb/
├── samyama-vldb.tex        # Main paper source
├── samyama-vldb.bib        # Bibliography
├── samyama-vldb.pdf        # Compiled PDF (submit this)
├── acmart.cls              # PVLDB document class
├── ACM-Reference-Format.bst # Bibliography style
├── figures/
│   ├── architecture.pdf    # System architecture diagram
│   ├── csr_layout.pdf      # CSR data layout
│   ├── pareto_front.pdf    # (unused in current version)
│   └── agentic_loop.pdf    # (unused in current version)
├── PLAN.md                 # Internal planning doc
└── SUBMISSION.md           # This file
```
