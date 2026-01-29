# Gitu Flutter App User Guide

Welcome to Gitu, your universal AI assistant within the NotebookLLM app. This guide will help you get started with using Gitu on your mobile device.

## Table of Contents
1. [Introduction](#introduction)
2. [Accessing Gitu](#accessing-gitu)
3. [Chat Interface](#chat-interface)
4. [Deep Research](#deep-research)
5. [Linking Terminal CLI](#linking-terminal-cli)
6. [Settings](#settings)

## Introduction
Gitu is integrated directly into the NotebookLLM app, providing a unified interface to access your notebooks, research tools, and external integrations like GitHub and Telegram.

## Accessing Gitu
You can access Gitu from the main navigation bar or the floating action button on the home screen.

- **Home Screen**: Tap the Gitu icon in the bottom navigation bar.
- **Quick Access**: Tap the floating AI button to instantly start a chat or voice command.

## Chat Interface
The chat interface is designed for seamless communication with Gitu.

### Features
- **Real-time Chat**: Converse naturally with Gitu.
- **Context Aware**: Gitu knows about your open notebooks and active projects.
- **Voice Mode**: Tap the microphone icon to speak to Gitu.
- **Attachments**: Upload images or files for analysis.

### Connection Status
The status badge at the top shows your connection state:
- **Green (Online)**: Connected and ready.
- **Orange (Connecting)**: Re-establishing connection.
- **Red (Offline)**: Disconnected. Check your internet connection.

## Deep Research
Gitu can perform deep research tasks that go beyond simple queries.

1. Navigate to the **Research** tab or ask Gitu to "research [topic]".
2. Gitu will browse the web, analyze multiple sources, and compile a comprehensive report.
3. You can view progress in real-time as Gitu finds and processes information.

## Linking Terminal CLI
You can control Gitu from your desktop terminal and sync it with your mobile app.

1. Go to **Settings > Terminal Connections**.
2. Tap **Scan QR Code**.
3. On your computer, run `gitu auth --qr`.
4. Scan the QR code displayed on your terminal.

Alternatively, you can generate a pairing token:
1. Tap **Generate Token** in the app.
2. Run `gitu auth <token>` on your terminal.

## Settings
Customize your Gitu experience in the Settings menu:

- **AI Model**: Choose your preferred model (e.g., Gemini Pro, GPT-4, Claude).
- **Voice Settings**: Change the text-to-speech voice and speed.
- **Notifications**: Manage alerts for task completions and research updates.
