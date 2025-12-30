"use client";

import React, { useState, useEffect } from "react";
import { motion, useAnimation } from "framer-motion";
import {
  Search,
  Globe,
  BrainCircuit,
  Sparkles,
  ArrowRight,
  Zap,
  ShieldCheck,
  BookOpen
} from "lucide-react";
import Image from "next/image";

export default function LandingPage() {
  return (
    <div className="min-h-screen bg-neutral-950 text-white selection:bg-blue-500/30">
      <Navbar />
      <HeroSection />
      <FeaturesSection />
      <Footer />
    </div>
  );
}

function Navbar() {
  return (
    <nav className="fixed top-0 left-0 right-0 z-50 border-b border-white/5 bg-neutral-950/50 backdrop-blur-xl">
      <div className="container mx-auto flex h-16 items-center justify-between px-6">
        <div className="flex items-center gap-2">
          <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-blue-600/20 text-blue-400">
            <BrainCircuit size={20} />
          </div>
          <span className="text-lg font-bold tracking-tight">NotebookLM</span>
        </div>
        <div className="hidden items-center gap-8 text-sm font-medium text-neutral-400 md:flex">
          <a href="#" className="hover:text-white transition-colors">Features</a>
          <a href="#" className="hover:text-white transition-colors">Pricing</a>
          <a href="#" className="hover:text-white transition-colors">Enterprise</a>
        </div>
        <div className="flex items-center gap-4">
          <a href="/login" className="text-sm font-medium text-white hover:text-blue-400">
            Log In
          </a>
          <button className="rounded-full bg-white px-4 py-2 text-sm font-semibold text-neutral-950 hover:bg-neutral-200 transition-colors">
            Download App
          </button>
        </div>
      </div>
    </nav>
  );
}

function HeroSection() {
  return (
    <section className="relative flex min-h-screen flex-col items-center justify-center overflow-hidden px-6 pt-20">
      {/* Background Gradients */}
      <div className="absolute top-1/4 -left-1/4 h-[500px] w-[500px] rounded-full bg-blue-600/20 blur-[120px]" />
      <div className="absolute bottom-1/4 -right-1/4 h-[500px] w-[500px] rounded-full bg-purple-600/10 blur-[120px]" />

      <div className="container relative mx-auto grid lg:grid-cols-2 gap-12 items-center">
        <div className="text-center lg:text-left">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6 }}
          >
            <div className="inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/5 px-3 py-1 text-xs font-medium backdrop-blur-md">
              <span className="flex h-2 w-2 rounded-full bg-green-500 animate-pulse" />
              New: Deep Research v2.0
            </div>
            <h1 className="mt-6 text-5xl font-bold tracking-tight sm:text-7xl bg-gradient-to-b from-white to-white/60 bg-clip-text text-transparent">
              Research at the <br /> speed of thought.
            </h1>
            <p className="mt-6 text-lg text-neutral-400 max-w-2xl mx-auto lg:mx-0">
              Transform how you gather information. Our autonomous AI agent dives deep into the web, analyzing thousands of sources to generate comprehensive reports in minutes.
            </p>
            <div className="mt-8 flex flex-col sm:flex-row items-center gap-4 justify-center lg:justify-start">
              <button className="group flex items-center gap-2 rounded-full bg-blue-600 px-6 py-3 font-semibold text-white hover:bg-blue-500 hover:shadow-lg hover:shadow-blue-500/20 transition-all">
                Download for iOS
                <ArrowRight size={18} className="transition-transform group-hover:translate-x-1" />
              </button>
              <button className="flex items-center gap-2 rounded-full border border-white/10 bg-white/5 px-6 py-3 font-semibold text-white hover:bg-white/10 transition-colors">
                <Search size={18} />
                View Demo
              </button>
            </div>
          </motion.div>
        </div>

        {/* 3D Core Demo */}
        <div className="relative flex items-center justify-center">
          <DeepResearchVisualizer />
        </div>
      </div>
    </section>
  );
}

function DeepResearchVisualizer() {
  const [status, setStatus] = useState("Initializing...");
  const [source, setSource] = useState<string | null>(null);

  useEffect(() => {
    const states = [
      { text: "Scanning academic sources...", domain: null },
      { text: "Found data on wikipedia.org", domain: "wikipedia.org" },
      { text: "Analyzing trends...", domain: null },
      { text: "Cross-referencing nature.com", domain: "nature.com" },
      { text: "Synthesizing report...", domain: null },
      { text: "Deep Research Active", domain: null },
    ];
    let i = 0;
    const interval = setInterval(() => {
      setStatus(states[i].text);
      setSource(states[i].domain);
      i = (i + 1) % states.length;
    }, 2500);
    return () => clearInterval(interval);
  }, []);

  return (
    <div className="relative h-[400px] w-[400px] flex items-center justify-center">
      {/* Rings */}
      <motion.div
        animate={{ rotateX: 360, rotateY: 180 }}
        transition={{ duration: 20, repeat: Infinity, ease: "linear" }}
        className="absolute h-64 w-64 rounded-full border border-blue-500/30 border-t-blue-400"
        style={{ transformStyle: "preserve-3d" }}
      />
      <motion.div
        animate={{ rotateX: -360, rotateY: -90 }}
        transition={{ duration: 15, repeat: Infinity, ease: "linear" }}
        className="absolute h-48 w-48 rounded-full border border-purple-500/30 border-b-purple-400"
        style={{ transformStyle: "preserve-3d" }}
      />

      {/* Core */}
      <div className="relative h-24 w-24 rounded-full bg-neutral-900 border border-white/10 shadow-[0_0_50px_-12px_rgba(59,130,246,0.5)] flex items-center justify-center z-10 backdrop-blur-xl">
        {source ? (
          <Image
            src={`https://www.google.com/s2/favicons?domain=${source}&sz=64`}
            width={40}
            height={40}
            alt="Source"
            className="opacity-90 grayscale hover:grayscale-0 transition-all"
          />
        ) : (
          <Globe className="text-blue-400 animate-pulse" size={40} />
        )}
      </div>

      {/* Floating Status Card */}
      <motion.div
        key={status}
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        exit={{ opacity: 0 }}
        className="absolute bottom-0 w-64 rounded-xl border border-white/10 bg-neutral-900/80 p-4 backdrop-blur-md shadow-xl"
      >
        <div className="flex items-center gap-3">
          <div className="flex h-2 w-2 relative">
            <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-blue-400 opacity-75"></span>
            <span className="relative inline-flex rounded-full h-2 w-2 bg-blue-500"></span>
          </div>
          <span className="text-sm font-medium text-neutral-200">{status}</span>
        </div>
        <div className="mt-3 h-1 w-full rounded-full bg-neutral-800 overflow-hidden">
          <motion.div
            className="h-full bg-blue-500"
            initial={{ width: "0%" }}
            animate={{ width: "100%" }}
            transition={{ duration: 2.5, ease: "linear", repeat: Infinity }}
          />
        </div>
      </motion.div>
    </div>
  );
}

function FeaturesSection() {
  const features = [
    {
      icon: <Zap className="text-amber-400" />,
      title: "Lightning Fast",
      desc: "Get comprehensive reports in minutes, not days. Our AI processes information faster than any human research team."
    },
    {
      icon: <ShieldCheck className="text-green-400" />,
      title: "Verified Sources",
      desc: "Every claim is backed by citations from credible academic, government, and industry sources."
    },
    {
      icon: <BookOpen className="text-purple-400" />,
      title: "Structured Reports",
      desc: "Receive beautifully formatted outputs with executive summaries, key findings, and actionable insights."
    }
  ];

  return (
    <section className="py-24 bg-neutral-900/30">
      <div className="container mx-auto px-6">
        <div className="grid md:grid-cols-3 gap-8">
          {features.map((feature, i) => (
            <div key={i} className="group p-8 rounded-2xl border border-white/5 bg-white/[0.02] hover:bg-white/[0.05] transition-colors">
              <div className="mb-4 inline-flex h-12 w-12 items-center justify-center rounded-xl bg-white/5 group-hover:bg-white/10 transition-colors">
                {feature.icon}
              </div>
              <h3 className="text-xl font-semibold text-white">{feature.title}</h3>
              <p className="mt-2 text-neutral-400 leading-relaxed">{feature.desc}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

function Footer() {
  return (
    <footer className="border-t border-white/5 bg-neutral-950 py-12">
      <div className="container mx-auto px-6 text-center text-neutral-500 text-sm">
        <p>© 2025 NotebookLM. Built for the future of research.</p>
      </div>
    </footer>
  );
}
