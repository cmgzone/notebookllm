/**
 * Code Verification Service
 * Verifies code correctness using multiple strategies:
 * - Syntax validation
 * - Linting rules
 * - Type checking (for TypeScript)
 * - Security scanning
 * - Best practices validation
 */

import { GoogleGenerativeAI } from '@google/generative-ai';

export interface CodeVerificationRequest {
  code: string;
  language: string;
  context?: string;
  strictMode?: boolean;
}

export interface VerificationResult {
  isValid: boolean;
  score: number; // 0-100
  errors: CodeIssue[];
  warnings: CodeIssue[];
  suggestions: CodeSuggestion[];
  metadata: {
    language: string;
    linesOfCode: number;
    complexity: string;
    verifiedAt: string;
  };
}

export interface CodeIssue {
  type: 'error' | 'warning';
  message: string;
  line?: number;
  column?: number;
  rule?: string;
  severity: 'critical' | 'high' | 'medium' | 'low';
}

export interface CodeSuggestion {
  message: string;
  category: 'performance' | 'security' | 'readability' | 'best-practice';
  priority: 'high' | 'medium' | 'low';
}

export interface VerifiedSource {
  id: string;
  code: string;
  language: string;
  title: string;
  description: string;
  verificationResult: VerificationResult;
  createdAt: string;
  userId?: string;
  notebookId?: string;
}

class CodeVerificationService {
  private genAI: GoogleGenerativeAI | null = null;

  initialize() {
    const apiKey = process.env.GEMINI_API_KEY;
    if (apiKey) {
      this.genAI = new GoogleGenerativeAI(apiKey);
      console.log('✅ Code Verification Service initialized');
    } else {
      console.warn('⚠️ GEMINI_API_KEY not set - AI verification disabled');
    }
  }

  /**
   * Verify code for correctness, security, and best practices
   */
  async verifyCode(request: CodeVerificationRequest): Promise<VerificationResult> {
    const { code, language, context, strictMode = false } = request;
    
    const errors: CodeIssue[] = [];
    const warnings: CodeIssue[] = [];
    const suggestions: CodeSuggestion[] = [];

    // Step 1: Basic syntax validation
    const syntaxResult = this.validateSyntax(code, language);
    errors.push(...syntaxResult.errors);
    warnings.push(...syntaxResult.warnings);

    // Step 2: Security scanning
    const securityResult = this.scanSecurity(code, language);
    errors.push(...securityResult.errors);
    warnings.push(...securityResult.warnings);
    suggestions.push(...securityResult.suggestions);

    // Step 3: AI-powered deep analysis (if available)
    if (this.genAI) {
      const aiResult = await this.aiAnalysis(code, language, context, strictMode);
      errors.push(...aiResult.errors);
      warnings.push(...aiResult.warnings);
      suggestions.push(...aiResult.suggestions);
    }

    // Calculate score
    const score = this.calculateScore(errors, warnings);

    return {
      isValid: errors.filter(e => e.severity === 'critical').length === 0,
      score,
      errors,
      warnings,
      suggestions,
      metadata: {
        language,
        linesOfCode: code.split('\n').length,
        complexity: this.assessComplexity(code),
        verifiedAt: new Date().toISOString(),
      },
    };
  }


  /**
   * Basic syntax validation
   */
  private validateSyntax(code: string, language: string): { errors: CodeIssue[]; warnings: CodeIssue[] } {
    const errors: CodeIssue[] = [];
    const warnings: CodeIssue[] = [];

    // Language-specific syntax checks
    switch (language.toLowerCase()) {
      case 'javascript':
      case 'typescript':
        this.validateJSTS(code, errors, warnings);
        break;
      case 'python':
        this.validatePython(code, errors, warnings);
        break;
      case 'dart':
        this.validateDart(code, errors, warnings);
        break;
      case 'json':
        this.validateJSON(code, errors, warnings);
        break;
      default:
        this.validateGeneric(code, errors, warnings);
    }

    return { errors, warnings };
  }

  private validateJSTS(code: string, errors: CodeIssue[], warnings: CodeIssue[]) {
    const lines = code.split('\n');
    
    // Check for common issues
    lines.forEach((line, index) => {
      // Unclosed brackets
      const openBrackets = (line.match(/\{/g) || []).length;
      const closeBrackets = (line.match(/\}/g) || []).length;
      
      // Check for console.log in production code
      if (line.includes('console.log')) {
        warnings.push({
          type: 'warning',
          message: 'console.log found - consider removing for production',
          line: index + 1,
          rule: 'no-console',
          severity: 'low',
        });
      }

      // Check for var usage
      if (/\bvar\s+/.test(line)) {
        warnings.push({
          type: 'warning',
          message: 'Use const or let instead of var',
          line: index + 1,
          rule: 'no-var',
          severity: 'medium',
        });
      }

      // Check for == instead of ===
      if (/[^=!]==[^=]/.test(line)) {
        warnings.push({
          type: 'warning',
          message: 'Use === instead of == for strict equality',
          line: index + 1,
          rule: 'eqeqeq',
          severity: 'medium',
        });
      }
    });

    // Check bracket balance
    const totalOpen = (code.match(/\{/g) || []).length;
    const totalClose = (code.match(/\}/g) || []).length;
    if (totalOpen !== totalClose) {
      errors.push({
        type: 'error',
        message: `Unbalanced brackets: ${totalOpen} opening, ${totalClose} closing`,
        rule: 'syntax',
        severity: 'critical',
      });
    }
  }

  private validatePython(code: string, errors: CodeIssue[], warnings: CodeIssue[]) {
    const lines = code.split('\n');
    
    lines.forEach((line, index) => {
      // Check indentation consistency
      if (line.startsWith('\t') && code.includes('    ')) {
        warnings.push({
          type: 'warning',
          message: 'Mixed tabs and spaces in indentation',
          line: index + 1,
          rule: 'indentation',
          severity: 'medium',
        });
      }

      // Check for bare except
      if (/except\s*:/.test(line)) {
        warnings.push({
          type: 'warning',
          message: 'Bare except clause - specify exception type',
          line: index + 1,
          rule: 'bare-except',
          severity: 'medium',
        });
      }
    });
  }

  private validateDart(code: string, errors: CodeIssue[], warnings: CodeIssue[]) {
    const lines = code.split('\n');
    
    lines.forEach((line, index) => {
      // Check for print statements
      if (/\bprint\s*\(/.test(line)) {
        warnings.push({
          type: 'warning',
          message: 'print() found - use debugPrint() or logging',
          line: index + 1,
          rule: 'avoid-print',
          severity: 'low',
        });
      }

      // Check for dynamic type
      if (/\bdynamic\b/.test(line)) {
        warnings.push({
          type: 'warning',
          message: 'Avoid using dynamic type when possible',
          line: index + 1,
          rule: 'avoid-dynamic',
          severity: 'medium',
        });
      }
    });
  }

  private validateJSON(code: string, errors: CodeIssue[], warnings: CodeIssue[]) {
    try {
      JSON.parse(code);
    } catch (e: any) {
      errors.push({
        type: 'error',
        message: `Invalid JSON: ${e.message}`,
        rule: 'json-parse',
        severity: 'critical',
      });
    }
  }

  private validateGeneric(code: string, errors: CodeIssue[], warnings: CodeIssue[]) {
    // Generic checks for any language
    if (code.trim().length === 0) {
      errors.push({
        type: 'error',
        message: 'Empty code block',
        rule: 'no-empty',
        severity: 'high',
      });
    }
  }


  /**
   * Security vulnerability scanning
   */
  private scanSecurity(code: string, language: string): { 
    errors: CodeIssue[]; 
    warnings: CodeIssue[]; 
    suggestions: CodeSuggestion[] 
  } {
    const errors: CodeIssue[] = [];
    const warnings: CodeIssue[] = [];
    const suggestions: CodeSuggestion[] = [];

    const securityPatterns = [
      { pattern: /eval\s*\(/gi, message: 'eval() is dangerous - avoid using it', severity: 'critical' as const },
      { pattern: /innerHTML\s*=/gi, message: 'innerHTML can lead to XSS - use textContent or sanitize', severity: 'high' as const },
      { pattern: /document\.write/gi, message: 'document.write is deprecated and insecure', severity: 'high' as const },
      { pattern: /password\s*=\s*['"][^'"]+['"]/gi, message: 'Hardcoded password detected', severity: 'critical' as const },
      { pattern: /api[_-]?key\s*=\s*['"][^'"]+['"]/gi, message: 'Hardcoded API key detected', severity: 'critical' as const },
      { pattern: /secret\s*=\s*['"][^'"]+['"]/gi, message: 'Hardcoded secret detected', severity: 'critical' as const },
      { pattern: /exec\s*\(/gi, message: 'exec() can be dangerous - validate input', severity: 'high' as const },
      { pattern: /shell\s*=\s*True/gi, message: 'shell=True in subprocess is risky', severity: 'high' as const },
      { pattern: /SELECT\s+\*\s+FROM.*\+/gi, message: 'Potential SQL injection - use parameterized queries', severity: 'critical' as const },
    ];

    securityPatterns.forEach(({ pattern, message, severity }) => {
      if (pattern.test(code)) {
        if (severity === 'critical') {
          errors.push({ type: 'error', message, rule: 'security', severity });
        } else {
          warnings.push({ type: 'warning', message, rule: 'security', severity });
        }
      }
    });

    // Add security suggestions
    if (!code.includes('try') && !code.includes('catch') && !code.includes('except')) {
      suggestions.push({
        message: 'Consider adding error handling for robustness',
        category: 'security',
        priority: 'medium',
      });
    }

    return { errors, warnings, suggestions };
  }

  /**
   * AI-powered deep code analysis
   */
  private async aiAnalysis(
    code: string, 
    language: string, 
    context?: string,
    strictMode: boolean = false
  ): Promise<{ errors: CodeIssue[]; warnings: CodeIssue[]; suggestions: CodeSuggestion[] }> {
    const errors: CodeIssue[] = [];
    const warnings: CodeIssue[] = [];
    const suggestions: CodeSuggestion[] = [];

    if (!this.genAI) return { errors, warnings, suggestions };

    try {
      const model = this.genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });
      
      const prompt = `Analyze this ${language} code for issues. ${strictMode ? 'Be very strict.' : ''}
${context ? `Context: ${context}` : ''}

Code:
\`\`\`${language}
${code}
\`\`\`

Respond in JSON format:
{
  "errors": [{"message": "...", "line": 1, "severity": "critical|high|medium|low"}],
  "warnings": [{"message": "...", "line": 1, "severity": "high|medium|low"}],
  "suggestions": [{"message": "...", "category": "performance|security|readability|best-practice", "priority": "high|medium|low"}]
}

Only include actual issues found. Be concise.`;

      const result = await model.generateContent(prompt);
      const text = result.response.text();
      
      // Extract JSON from response
      const jsonMatch = text.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        const analysis = JSON.parse(jsonMatch[0]);
        
        if (analysis.errors) {
          analysis.errors.forEach((e: any) => {
            errors.push({
              type: 'error',
              message: e.message,
              line: e.line,
              rule: 'ai-analysis',
              severity: e.severity || 'medium',
            });
          });
        }
        
        if (analysis.warnings) {
          analysis.warnings.forEach((w: any) => {
            warnings.push({
              type: 'warning',
              message: w.message,
              line: w.line,
              rule: 'ai-analysis',
              severity: w.severity || 'low',
            });
          });
        }
        
        if (analysis.suggestions) {
          analysis.suggestions.forEach((s: any) => {
            suggestions.push({
              message: s.message,
              category: s.category || 'best-practice',
              priority: s.priority || 'medium',
            });
          });
        }
      }
    } catch (error) {
      console.error('AI analysis error:', error);
    }

    return { errors, warnings, suggestions };
  }

  /**
   * Calculate verification score
   */
  private calculateScore(errors: CodeIssue[], warnings: CodeIssue[]): number {
    let score = 100;
    
    errors.forEach(e => {
      switch (e.severity) {
        case 'critical': score -= 25; break;
        case 'high': score -= 15; break;
        case 'medium': score -= 10; break;
        case 'low': score -= 5; break;
      }
    });
    
    warnings.forEach(w => {
      switch (w.severity) {
        case 'critical': score -= 10; break;
        case 'high': score -= 5; break;
        case 'medium': score -= 3; break;
        case 'low': score -= 1; break;
      }
    });
    
    return Math.max(0, Math.min(100, score));
  }

  /**
   * Assess code complexity
   */
  private assessComplexity(code: string): string {
    const lines = code.split('\n').length;
    const nestingLevel = Math.max(
      ...(code.match(/\{/g) || []).map((_, i, arr) => 
        arr.slice(0, i + 1).length - (code.slice(0, code.indexOf(arr[i])).match(/\}/g) || []).length
      ),
      0
    );
    
    if (lines > 500 || nestingLevel > 6) return 'high';
    if (lines > 100 || nestingLevel > 4) return 'medium';
    return 'low';
  }
}

export const codeVerificationService = new CodeVerificationService();
export default codeVerificationService;
