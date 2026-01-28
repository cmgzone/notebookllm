# Design Document: Gitu - Universal AI Assistant

## Overview

Gitu is an autonomous, multi-platform AI assistant that operates as a background service, accessible through WhatsApp (via Baileys), Telegram, email, terminal, and the NotebookLLM Flutter app. The system is designed with the NotebookLLM Flutter app as the primary configuration interface, allowing users to manage API keys, select AI models, configure integrations, and control all aspects of Gitu's behavior.

## Vision

Create an always-available, context-aware AI assistant that:
- Works across all user touchpoints (WhatsApp, Telegram, email, terminal, Flutter app)
- Maintains persistent memory and session context
- Integrates with user's digital ecosystem (Gmail, Shopify, Notebooks, Files)
- Operates autonomously with strict permission controls
- Respects user's AI model preferences from NotebookLLM app
- Supports both platform API keys and user's personal keys

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         User Touchpoints                                     │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │ Flutter  │  │ WhatsApp │  │ Telegram │  │  Email   │  │ Terminal │    │
│  │   App    │  │ (Baileys)│  │   Bot    │  │  (IMAP)  │  │   CLI    │    │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘    │
└───────┼─────────────┼─────────────┼─────────────┼─────────────┼───────────┘
        │             │             │             │             │
        └─────────────┴─────────────┴─────────────┴─────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Message Gateway                                      │
│  • Platform adapters (WhatsApp, Telegram, Email, CLI)                      │
│  • Message normalization and routing                                        │
│  • User identification and session management                               │
└─────────────────────────────┬───────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Gitu Core Service                                    │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │   Session    │  │    Memory    │  │     AI       │  │  Permission  │  │
│  │   Manager    │  │    System    │  │   Router     │  │   Manager    │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘  │
└─────────────────────────────┬───────────────────────────────────────────────┘
                              │
