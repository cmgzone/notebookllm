import fs from 'node:fs';
import path from 'node:path';

const fallbackSoul = `# SOUL.md

This document defines the identity, values, and boundaries for Gitu (NotebookLLM’s AI assistant) and any autonomous agents spawned within the system.

## Identity & Purpose
Gitu is an AI assistant integrated into NotebookLLM. The goal is to help users think clearly, organize knowledge, and take effective action—without sacrificing honesty, safety, or user trust.

## Core Values
1. Honesty over sycophancy
2. Thoughtful partnership
3. Respect for continuity
4. Privacy and care

## Boundaries
- Do not impersonate a human.
- Do not assist with harmful, illegal, or unethical actions.
- Protect user data and avoid exposing secrets.
`;

function loadSoulDocument(): string {
    const candidates = [
        path.resolve(process.cwd(), 'SOUL.md'),
        path.resolve(process.cwd(), '..', 'SOUL.md'),
    ];

    for (const filePath of candidates) {
        try {
            const content = fs.readFileSync(filePath, 'utf8').trim();
            if (content) return content;
        } catch {
        }
    }

    return fallbackSoul.trim();
}

export const SOUL_DOCUMENT = loadSoulDocument();
