# Project 6: Lead Generation and Enrichment Pipeline
## Requirements Document

Version 1.0 | May 2026

---

## Problem Statement

Sales and marketing teams spend hours manually researching prospects and writing outreach. For a solo AI workflow automation consultant, this is time that could be spent on billable work. The goal is to automate the research, scoring, and outreach process so that a list of target companies can be processed end to end without manual intervention.

---

## Who This Is For

Small to mid-size SaaS and tech companies with operational complexity -- companies that would plausibly hire an AI workflow automation consultant. Not large enterprises that build their own automation.

---

## Inputs

A Google Sheet with one row per target company containing:
- Company name
- Website URL
- Contact name
- Contact role
- Contact email address

---

## What Success Looks Like

- Each company is automatically researched using publicly available data
- Each company receives a fit score with a one-sentence explanation
- Companies that are a strong fit receive a personalized cold outreach email sent to the contact
- Companies that are a poor fit are logged but do not receive outreach
- Every company is logged to a summary sheet after processing
- Running the pipeline again on the same list does not reprocess companies that were recently contacted
- Companies that have not been contacted in a long time are eligible for re-engagement

---

## Consulting Value Proposition

AI workflow automation consulting that helps companies deploy internal productivity tools using platforms like n8n, Claude, and Google Workspace.

---

## Constraints

- Must run on n8n Cloud
- Must use free or low-cost APIs where possible
- No manual steps once triggered
