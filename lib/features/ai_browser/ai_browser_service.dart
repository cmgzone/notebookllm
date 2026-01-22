import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/api/api_service.dart';
import '../../core/ai/ai_settings_service.dart';
import 'models/ai_product.dart';

/// Service for AI-controlled browser interactions
class AIBrowserService {
  final Ref ref;
  WebViewController? _controller;
  final _statusController = StreamController<AIBrowserUpdate>.broadcast();
  bool _isPaused = false;
  final List<AIProduct> _collectedProducts = [];
  final List<String> _userInterventions = [];

  List<AIProduct> get collectedProducts =>
      List.unmodifiable(_collectedProducts);

  void addUserMessage(String message) {
    _userInterventions.add(message);
  }

  void pause() {
    _isPaused = true;
    _statusController.add(AIBrowserUpdate(
      status: '⏸️ Paused (Tap Resume to continue)',
      action: AIBrowserAction.waiting,
    ));
  }

  void resume() => _isPaused = false;

  Stream<AIBrowserUpdate> get statusStream => _statusController.stream;

  AIBrowserService(this.ref);

  void setController(WebViewController controller) {
    _controller = controller;
  }

  Completer<ProductFeedback>? _userFeedbackCompleter;
  Completer<String>? _screenshotCompleter;

  void provideFeedback(bool liked, {Uint8List? screenshotBytes}) {
    if (_userFeedbackCompleter != null &&
        !_userFeedbackCompleter!.isCompleted) {
      _userFeedbackCompleter!.complete(ProductFeedback(
        liked: liked,
        screenshotBytes: screenshotBytes,
      ));
    }
  }

  Future<void> processVisionScreenshot(Uint8List screenshot) async {
    if (_screenshotCompleter != null && !_screenshotCompleter!.isCompleted) {
      final base64Image = base64Encode(screenshot);
      _screenshotCompleter!.complete(base64Image);
    }
  }

  /// Execute AI-driven browsing based on user query
  Stream<AIBrowserUpdate> browse({
    required String query,
    String? currentUrl,
    String? pageContent,
    Duration? maxDuration,
  }) async* {
    if (_controller == null) {
      yield AIBrowserUpdate(
        status: 'Error: Browser not initialized',
        isComplete: true,
      );
      return;
    }

    final startTime = DateTime.now();
    final timeout = maxDuration ?? const Duration(minutes: 2);
    final history = <String>[];
    bool isTaskComplete = false;
    String finalResponseText = '';

    yield AIBrowserUpdate(
      status: '🤔 Analyzing your request...',
      action: AIBrowserAction.thinking,
    );

    try {
      while (
          DateTime.now().difference(startTime) < timeout && !isTaskComplete) {
        // PAUSE CHECK
        while (_isPaused) {
          yield AIBrowserUpdate(
            status: '⏸️ Paused (Tap Resume to continue)',
            action: AIBrowserAction.waiting,
          );
          await Future.delayed(const Duration(milliseconds: 500));
        }

        // PROCESS USER INTERVENTIONS (Voice/Text commands)
        if (_userInterventions.isNotEmpty) {
          for (final msg in _userInterventions) {
            history.add('USER INTERVENTION: $msg');
            yield AIBrowserUpdate(
              status: '👂 Heard: "$msg"',
              action: AIBrowserAction.thinking,
            );
          }
          _userInterventions.clear();
        }

        // Get current page info
        final url = await _controller!.currentUrl() ?? 'about:blank';
        final title = await _controller!.getTitle() ?? '';
        final content = await getPageContent();

        // Ask AI what to do
        final aiPlan = await _getAIPlan(
          query: query,
          currentUrl: url,
          pageTitle: title,
          pageContent: content,
          history: history,
        );

        yield AIBrowserUpdate(
          status: '📋 Plan: ${aiPlan.explanation}',
          action: AIBrowserAction.planning,
        );

        // Execute each action
        for (final action in aiPlan.actions) {
          if (action.type == 'complete') {
            isTaskComplete = true;
            finalResponseText = action.text ?? 'Task completed successfully.';
            break;
          }

          if (action.type == 'fail') {
            isTaskComplete = true;
            finalResponseText = action.text ?? 'Unable to complete the task.';
            break;
          }

          if (action.type == 'record_finding') {
            final finding = action.text ?? 'No finding recorded';
            history.add('Finding: $finding');
            // Show user we found something
            yield AIBrowserUpdate(
              status:
                  '💡 Found: ${finding.length > 50 ? "${finding.substring(0, 50)}..." : finding}',
              action: AIBrowserAction.thinking,
              isFinding: true,
              findingText: finding,
            );
            await Future.delayed(const Duration(milliseconds: 800));
            continue;
          }

          if (action.type == 'propose_product') {
            final productName = action.text ?? 'Unknown Product';

            // Prepare waiter for user feedback (with screenshot)
            _userFeedbackCompleter = Completer<ProductFeedback>();

            // Notify UI
            yield AIBrowserUpdate(
              status: '🧐 Found product: $productName. Do you like it?',
              action: AIBrowserAction.waitingForFeedback,
              isProduct: true,
              productTitle: productName,
              productPrice: action.price,
              productDescription: action.description,
              productImageUrl: action.imageUrl,
            );

            // Wait for feedback or timeout (45s if user ignores)
            ProductFeedback? feedback;
            try {
              feedback = await _userFeedbackCompleter!.future
                  .timeout(const Duration(seconds: 45));
            } catch (e) {
              // Timeout, assume user didn't respond
              feedback = null;
            }

            if (feedback != null && feedback.liked) {
              history.add('User LIKED product: $productName');

              // Add to collection tray WITH screenshot
              _collectedProducts.add(AIProduct(
                title: productName,
                price: action.price ?? 'Unknown',
                description: action.description ?? '',
                imageUrl: action.imageUrl,
                url: url, // Current page URL where product was found
                screenshotBytes:
                    feedback.screenshotBytes, // Save the screenshot!
              ));

              yield AIBrowserUpdate(
                status: '❤️ Saved to comparison tray! Looking for more...',
                action: AIBrowserAction.thinking,
              );
            } else {
              history.add('User DISLIKED product: $productName');
              yield AIBrowserUpdate(
                status: '👎 Understood. I\'ll avoid items like this.',
                action: AIBrowserAction.thinking,
              );
            }
            await Future.delayed(const Duration(seconds: 2));
            continue;
          }

          if (action.type == 'look') {
            // Request screenshot from UI
            _screenshotCompleter = Completer<String>();

            yield AIBrowserUpdate(
              status: '👀 Looking at the page...',
              action: AIBrowserAction.takingScreenshot,
            );

            // Wait for screenshot from UI
            try {
              final base64Image = await _screenshotCompleter!.future.timeout(
                  const Duration(seconds: 10)); // 10s timeout for screenshot

              // Analyze with Vision
              yield AIBrowserUpdate(
                status: '🧠 Analyzing visual content...',
                action: AIBrowserAction.thinking,
              );

              final visionPrompt = action.text ??
                  "Describe what you see on this page relevant to: $query";
              final visionResponse =
                  await ref.read(apiServiceProvider).chatWithVision(
                messages: [
                  {'role': 'user', 'content': visionPrompt}
                ],
                imageBase64: base64Image,
              );

              history.add('Analyzed Screenshot: $visionResponse');

              yield AIBrowserUpdate(
                status: '💡 Vision analysis complete.',
                action: AIBrowserAction.thinking,
              );
            } catch (e) {
              history.add('Failed to analyze screenshot: $e');
              debugPrint('Vision error: $e');
            }
            await Future.delayed(const Duration(milliseconds: 500));
            continue;
          }

          // PAUSE CHECK (Check between actions too)
          while (_isPaused) {
            yield AIBrowserUpdate(
              status: '⏸️ Paused (Tap Resume to continue)',
              action: AIBrowserAction.waiting,
            );
            await Future.delayed(const Duration(milliseconds: 500));
          }

          yield* _executeAction(action);

          // Log action to history
          history.add(
              'Action: ${action.type}, Details: ${action.selector ?? action.url ?? action.text ?? ''}');

          await Future.delayed(const Duration(milliseconds: 500));
        }

        // Check timeout
        if (DateTime.now().difference(startTime) >= timeout) {
          finalResponseText =
              'Task timed out after ${timeout.inMinutes} minutes.';
          isTaskComplete = true;
        }

        if (!isTaskComplete) {
          yield AIBrowserUpdate(
            status: '👀 Analyzing results...',
            action: AIBrowserAction.thinking,
          );
          await Future.delayed(const Duration(seconds: 1));
        }
      }

      // If we finished nicely or timed out, generate a final summary if we don't have one
      if (finalResponseText.isEmpty) {
        // Get final page content and generate response if not already set
        final finalContent = await getPageContent();
        final finalUrl = await _controller!.currentUrl() ?? '';

        yield AIBrowserUpdate(
          status: '💭 Generating final report...',
          action: AIBrowserAction.thinking,
        );

        finalResponseText = await _generateResponse(
          query: query,
          pageContent: finalContent,
          url: finalUrl,
          history: history,
        );
      }

      yield AIBrowserUpdate(
        status: '✅ Complete',
        action: AIBrowserAction.complete,
        isComplete: true,
        finalResponse: finalResponseText,
        currentUrl: await _controller!.currentUrl(),
      );
    } catch (e) {
      debugPrint('AI Browser error: $e');
      yield AIBrowserUpdate(
        status: '❌ Error: $e',
        isComplete: true,
      );
    }
  }

  Stream<AIBrowserUpdate> _executeAction(BrowserAction action) async* {
    switch (action.type) {
      case 'navigate':
        yield AIBrowserUpdate(
          status: '🌐 Navigating to ${action.url}...',
          action: AIBrowserAction.navigating,
        );
        if (action.url != null) {
          await _controller!.loadRequest(Uri.parse(action.url!));
          await _waitForPageLoad();
        }

      case 'click':
        yield AIBrowserUpdate(
          status: '👆 Clicking "${action.selector ?? 'element'}"...',
          action: AIBrowserAction.clicking,
        );
        if (action.selector != null) {
          await clickElement(action.selector!);
          await Future.delayed(const Duration(
              milliseconds: 2000)); // Increased wait time for visibility
        }

      case 'type':
        yield AIBrowserUpdate(
          status: '⌨️ Typing "${action.text}"...',
          action: AIBrowserAction.typing,
        );
        if (action.selector != null && action.text != null) {
          await _typeInElement(action.selector!, action.text!);
        }

      case 'scroll':
        yield AIBrowserUpdate(
          status: '📜 Scrolling ${action.direction}...',
          action: AIBrowserAction.scrolling,
        );
        await _scroll(action.direction ?? 'down', action.amount ?? 400);
        // Wait for smooth scroll animation to complete
        await Future.delayed(const Duration(milliseconds: 800));

      case 'wait':
        yield AIBrowserUpdate(
          status: '⏳ Waiting...',
          action: AIBrowserAction.waiting,
        );
        await Future.delayed(Duration(milliseconds: action.duration ?? 1000));

      case 'extract':
        yield AIBrowserUpdate(
          status: '📄 Reading page content...',
          action: AIBrowserAction.extracting,
        );
      // Content extraction happens automatically
    }
  }

  Future<String> getPageContent() async {
    try {
      final result = await _controller!.runJavaScriptReturningResult('''
        (function() {
          function getVisibleText(node) {
            if (node.nodeType === Node.TEXT_NODE) {
              return node.textContent.trim();
            }
            if (node.nodeType !== Node.ELEMENT_NODE) return '';
            if (node.tagName === 'SCRIPT' || node.tagName === 'STYLE' || node.tagName === 'NOSCRIPT' || node.tagName === 'SVG') return '';
            
            // Fast visibility checks
            if (node.hidden || node.style.display === 'none' || node.style.visibility === 'hidden') return '';
            
            let result = '';
            
            // Add image info accessible to AI
            if (node.tagName === 'IMG') {
               const alt = node.getAttribute('alt') || node.getAttribute('aria-label') || node.getAttribute('title');
               if (alt && alt.trim().length > 0) result += ' [Image: ' + alt.trim() + '] ';
            }
            
            // Add input info
            if (node.tagName === 'INPUT' || node.tagName === 'TEXTAREA') {
               const ph = node.getAttribute('placeholder') || node.getAttribute('aria-label') || node.name || node.type;
               if (ph) result += ' [Input: ' + ph + '] ';
            }
            
            // Process children
            for (let child of node.childNodes) {
              let childText = getVisibleText(child);
              if (childText.length > 0) result += childText + ' ';
            }
            
            // Block level separation
            const tag = node.tagName;
            if (tag === 'DIV' || tag === 'P' || tag === 'H1' || tag === 'H2' || tag === 'H3' || tag === 'LI' || tag === 'TR' || tag === 'ARTICLE' || tag === 'SECTION') {
              result += '\\n';
            }
            
            return result;
          }
          
          // Get main content or fallback to body
          const main = document.querySelector('main, article, .content, #content, .main') || document.body;
          const scrollPct = Math.round((window.scrollY + window.innerHeight) / document.body.scrollHeight * 100);
          return 'Scroll Position: ' + scrollPct + '%\\n\\n' + getVisibleText(main).replace(/\\s+/g, ' ').substring(0, 25000);
        })()
      ''');
      return result.toString().replaceAll('"', '');
    } catch (e) {
      return '';
    }
  }

  Future<void> clickElement(String selector) async {
    await _controller!.runJavaScript('''
      (function() {
        // Enhanced element finding with multiple strategies
        function findElement(selector) {
          selector = selector || '';
          // Strategy 1: Direct CSS selector
          try {
            let el = document.querySelector(selector);
            if (el) return el;
          } catch(e) {}
          
          // Strategy 2: By text content (links, buttons, spans)
          const clickables = document.querySelectorAll('a, button, [role="button"], input[type="submit"], input[type="button"], [onclick], .btn, .button, h1, h2, h3, h4, h5, h6');
          const searchText = selector.toLowerCase().trim();
          
          for (const e of clickables) {
            const text = (e.innerText || e.textContent || '').toLowerCase().trim();
            if (text === searchText || (text.length > 0 && text.includes(searchText))) {
              return e;
            }
          }
          
          // Strategy 3: By aria-label
          try {
            el = document.querySelector('[aria-label*="' + selector + '" i]');
            if (el) return el;
          } catch(e) {}
          
          // Strategy 4: By title attribute
          try {
            el = document.querySelector('[title*="' + selector + '" i]');
            if (el) return el;
          } catch(e) {}
          
          // Strategy 5: By placeholder
          try {
            el = document.querySelector('[placeholder*="' + selector + '" i]');
            if (el) return el;
          } catch(e) {}
          
          // Strategy 6: By class or ID containing the text
          try {
            el = document.querySelector('[class*="' + selector + '" i], [id*="' + selector + '" i]');
            if (el) return el;
          } catch(e) {}
          
          // Strategy 7: Search in nested elements (spans inside buttons)
          for (const e of document.querySelectorAll('button, a, [role="button"]')) {
            const nested = e.querySelector('span, div, p');
            if (nested) {
              const nestedText = (nested.innerText || '').toLowerCase().trim();
              if (nestedText === searchText || nestedText.includes(searchText)) {
                return e;
              }
            }
          }
          
          // Strategy 8: By role and name combo
          try {
            el = document.querySelector('[role="button"][name*="' + selector + '" i]');
            if (el) return el;
          } catch(e) {}

          // Strategy 9: By Image Alt, Src, or Data-Src (handling lazy load)
          try {
            // Check for standard src, but also common lazy-load attributes
            el = document.querySelector('img[alt*="' + selector + '" i], img[src*="' + selector + '" i], img[data-src*="' + selector + '" i], img[data-original*="' + selector + '" i]');
            if (el) return el.closest('a') || el.closest('button') || el;
          } catch(e) {}
          
          return null;
        }
        
        // Simulate real click events
        function simulateClick(element) {
          const rect = element.getBoundingClientRect();
          const x = rect.left + rect.width / 2;
          const y = rect.top + rect.height / 2;
          
          // Create and dispatch mouse events
          const eventOptions = {
            bubbles: true,
            cancelable: true,
            view: window,
            clientX: x,
            clientY: y,
            button: 0
          };
          
          element.dispatchEvent(new MouseEvent('mousedown', eventOptions));
          element.dispatchEvent(new MouseEvent('mouseup', eventOptions));
          element.dispatchEvent(new MouseEvent('click', eventOptions));
          
          // Also try native click as fallback
          if (element.click) {
            element.click();
          }
          
          // For input submit buttons
          if (element.tagName === 'INPUT' && (element.type === 'submit' || element.type === 'button')) {
            const form = element.closest('form');
            if (form) {
              form.requestSubmit ? form.requestSubmit() : form.submit();
            }
          }
        }
        
        const el = findElement('$selector');
        
        if (el) {
          el.scrollIntoView({behavior: 'smooth', block: 'center'});
          
          // --- VISUAL FEEDBACK START ---
          // Create Hand Cursor
          const cursor = document.createElement('div');
          cursor.innerText = '👆';
          cursor.style.cssText = 'position:fixed;font-size:40px;z-index:999999;pointer-events:none;transform:translate(50px, 50px);transition:all 0.8s cubic-bezier(0.22, 1, 0.36, 1);top:50%;left:50%;opacity:0;';
          document.body.appendChild(cursor);
          
          const originalOutline = el.style.outline;
          el.style.outline = '4px solid #FFD700';
          el.style.outlineOffset = '2px';
          
          requestAnimationFrame(() => {
            const rect = el.getBoundingClientRect();
            const targetTop = rect.top + rect.height/2;
            const targetLeft = rect.left + rect.width/2;
            
            cursor.style.opacity = '1';
            cursor.style.transform = 'translate(-10px, 0px)'; // Adjust for finger tip
            cursor.style.top = targetTop + 'px';
            cursor.style.left = targetLeft + 'px';
            
            setTimeout(() => {
              // Press effect
              cursor.style.transform = 'translate(-10px, 0px) scale(0.9)';
              
              // Perform click
              simulateClick(el);
              
              setTimeout(() => {
                if(cursor.parentNode) document.body.removeChild(cursor);
                el.style.outline = originalOutline;
                el.style.outlineOffset = '';
              }, 500);
            }, 900); // Wait for movement
          });
          // --- VISUAL FEEDBACK END ---
        } else {
          console.log('AI Browser: Could not find element: ' + '$selector');
        }
      })()
    ''');
  }

  Future<void> _typeInElement(String selector, String text) async {
    await _controller!.runJavaScript('''
      (function() {
        // Enhanced input field finding with multiple strategies
        function findInputField(selector) {
          // Strategy 1: Direct CSS selector
          let el = document.querySelector(selector);
          if (el) return el;
          
          // Strategy 2: Common input types
          el = document.querySelector('input[type="text"], input[type="search"], input:not([type]), textarea, [contenteditable="true"]');
          if (el) return el;
          
          // Strategy 3: By name or id containing "search" or "query"
          el = document.querySelector('input[name*="search" i], input[name*="query" i], input[name*="q" i], input[id*="search" i]');
          if (el) return el;
          
          // Strategy 4: By placeholder
          el = document.querySelector('input[placeholder*="search" i], input[placeholder*="type" i], input[placeholder*="enter" i]');
          if (el) return el;
          
          // Strategy 5: By aria-label
          el = document.querySelector('input[aria-label*="search" i], textarea[aria-label]');
          if (el) return el;
          
          // Strategy 6: Active/focused element if it's an input
          if (document.activeElement && (document.activeElement.tagName === 'INPUT' || document.activeElement.tagName === 'TEXTAREA')) {
            return document.activeElement;
          }
          
          // Strategy 7: Google-specific (they use a special structure)
          el = document.querySelector('textarea[name="q"], input[name="q"]');
          if (el) return el;
          
          return null;
        }
        
        // Simulate realistic typing with proper events
        function simulateTyping(element, text) {
          // Focus the element
          element.focus();
          
          // Clear existing value
          element.value = '';
          
          // Set the value directly (fastest)
          element.value = text;
          
          // Dispatch comprehensive events for React/Vue/Angular compatibility
          element.dispatchEvent(new Event('focus', { bubbles: true }));
          element.dispatchEvent(new Event('input', { bubbles: true, composed: true }));
          element.dispatchEvent(new Event('change', { bubbles: true }));
          
          // For React controlled components
          const nativeInputValueSetter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value')?.set;
          if (nativeInputValueSetter) {
            nativeInputValueSetter.call(element, text);
            element.dispatchEvent(new Event('input', { bubbles: true }));
          }
        }
        
        const el = findInputField('$selector');
        
        if (el) {
          el.scrollIntoView({behavior: 'smooth', block: 'center'});
          
          // --- VISUAL FEEDBACK START ---
          const originalBg = el.style.backgroundColor;
          const originalOutline = el.style.outline;
          
          el.style.outline = '3px solid #4CAF50';
          el.style.backgroundColor = 'rgba(255, 230, 0, 0.15)';
          
          // Simulate typing
          simulateTyping(el, '$text');
          
          setTimeout(() => {
            // Fade out highlight
            el.style.backgroundColor = originalBg;
            el.style.outline = originalOutline;
            
            // Try to submit
            const form = el.closest('form');
            if (form) {
              // Try Enter key first (more natural)
              el.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', code: 'Enter', keyCode: 13, which: 13, bubbles: true }));
              el.dispatchEvent(new KeyboardEvent('keypress', { key: 'Enter', code: 'Enter', keyCode: 13, which: 13, bubbles: true }));
              el.dispatchEvent(new KeyboardEvent('keyup', { key: 'Enter', code: 'Enter', keyCode: 13, which: 13, bubbles: true }));
              
              // Fallback to form submit after a short delay
              setTimeout(() => {
                // Check if page is still on same URL (Enter didn't work)
                if (form.requestSubmit) {
                  form.requestSubmit();
                } else {
                  form.submit();
                }
              }, 300);
            } else {
              // No form, try Enter key anyway (for standalone inputs)
              el.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', code: 'Enter', keyCode: 13, which: 13, bubbles: true }));
            }
          }, 800);
          // --- VISUAL FEEDBACK END ---
        } else {
          console.log('AI Browser: Could not find input field: ' + '$selector');
        }
      })()
    ''');
  }

  Future<void> _scroll(String direction, int amount) async {
    await _controller!.runJavaScript('''
      (function() {
        // Determine scroll target
        let scrollAmount = ${direction == 'up' ? -amount : amount};
        
        // Handle special directions
        if ('$direction' === 'top') {
          window.scrollTo({ top: 0, behavior: 'smooth' });
          return;
        }
        if ('$direction' === 'bottom') {
          window.scrollTo({ top: document.body.scrollHeight, behavior: 'smooth' });
          return;
        }
        
        // --- VISUAL FEEDBACK START ---
        // Create scroll indicator
        const indicator = document.createElement('div');
        indicator.innerHTML = '$direction' === 'up' ? '⬆️' : '⬇️';
        indicator.style.cssText = 'position:fixed;top:50%;left:50%;transform:translate(-50%,-50%);font-size:48px;z-index:999999;pointer-events:none;opacity:0;transition:opacity 0.3s ease;text-shadow:0 2px 10px rgba(0,0,0,0.5)';
        document.body.appendChild(indicator);
        
        // Show indicator
        requestAnimationFrame(() => {
          indicator.style.opacity = '1';
        });
        
        // Perform smooth scroll
        window.scrollBy({
          top: scrollAmount,
          behavior: 'smooth'
        });
        
        // Remove indicator after scroll
        setTimeout(() => {
          indicator.style.opacity = '0';
          setTimeout(() => {
            if (indicator.parentNode) document.body.removeChild(indicator);
          }, 300);
        }, 500);
        // --- VISUAL FEEDBACK END ---
      })()
    ''');
  }

  Future<void> _waitForPageLoad() async {
    // Wait for page to load - minimal wait, we rely on loop
    await Future.delayed(const Duration(seconds: 3));
  }

  Future<AIPlan> _getAIPlan({
    required String query,
    required String currentUrl,
    required String pageTitle,
    required String pageContent,
    required List<String> history,
  }) async {
    final historyText = history.isEmpty ? "None" : history.join('\n- ');

    // Extract findings from history to show them clearly
    final findings = history
        .where((h) => h.startsWith('Finding: '))
        .map((h) => h.replaceFirst('Finding: ', ''))
        .toList();
    final findingsText = findings.isEmpty ? "None yet." : findings.join('\n- ');

    final prompt = '''
You are an intelligent autonomous browser agent. Your goal is to fulfill the User Request by navigating, browsing, clicking, and EXTRACTING findings.
This is a multi-step process. You must ACCUMULATE knowledge over time.

USER REQUEST: $query

CURRENT STATE:
- URL: $currentUrl
- Page Title: $pageTitle

HISTORY OF ACTIONS:
- $historyText

ACCUMULATED FINDINGS (What you have learned so far):
- $findingsText

CURRENT PAGE CONTENT (truncated):
${pageContent.substring(0, (pageContent.length > 5000 ? 5000 : pageContent.length))}

Based on the history and current page, decide what to do next.

EXPLORATION RULES:
1. DO NOT stop at the first result.
2. You MUST use 'scroll' actions (direction: 'down') to see more results.
3. You MUST 'click' on individual product/article images or links to see details. Images appear as [Image: ...].
4. BOTTOM OF PAGE STRATEGY: If 'Scroll Position' is near 100% (or you have scrolled a lot):
   - If not satisfied, you MUST either click 'Next Page' / 'More Results' OR scroll 'up' to check for missed items.
   - Do not just stay at the bottom.
5. If you are on a search results page, 'scroll' at least once before clicking anything.
6. For popups, try to close them if they block the view.

PRODUCT DISCOVERY:
If you find a SPECIFIC product that matches the User Request, use the 'propose_product' action! This will show the product to the user and ask "Do you like this?".
- Extract the product title, price, description, and an image URL if possible.
- This is better than just 'record_finding' for physical products (clothes, gadgets, etc).
- Only propose one product at a time.
- Wait for the user's feedback (which will appear in HISTORY next turn) before proposing similar or different items.

Example of Product Discovery Actions:
{"type": "propose_product", "text": "Nike Air Max 90", "price": "\$120", "description": "Classic white sneakers", "imageUrl": "https://..."}

CRITICAL: If you see information relevant to the User Request on this page, use the 'record_finding' action to save it before navigating away!
If you have found the answer or completed the task, use the 'complete' action with a summary.
If the task is impossible, use 'fail' action.

Return a JSON object with:
{
  "explanation": "Reasoning for these actions",
  "actions": [
    {"type": "navigate", "url": "https://..."},
    {"type": "click", "selector": "button name or css selector"},
    {"type": "type", "selector": "input selector", "text": "search query"},
    {"type": "scroll", "direction": "down", "amount": 500},
    {"type": "wait", "duration": 2000},
    {"type": "record_finding", "text": "The price of the item is \$50."},
    {"type": "propose_product", "text": "Product Name", "price": "\$99", "description": "Desc", "imageUrl": "URL"},
    {"type": "propose_product", "text": "Product Name", "price": "\$99", "description": "Desc", "imageUrl": "URL"},
    {"type": "look", "text": "Describe the chart on the screen"},
    {"type": "complete", "text": "I have found the answer: ..."},
    {"type": "fail", "text": "I could not find the answer because..."}
  ]
}

VISUAL UNDERSTANDING:
If you need to SEE the page (e.g. to understand a chart, layout, image, or if text extraction is failing), use the 'look' action.
- "text": The specific question you want the Vision AI to answer about the screenshot.

Return ONLY valid JSON.
''';

    final response = await _callAI(prompt);
    return _parsePlan(response);
  }

  AIPlan _parsePlan(String response) {
    try {
      // Extract JSON from response
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(response);
      if (jsonMatch == null) {
        return AIPlan(
          explanation: 'Reading current page',
          actions: [BrowserAction(type: 'extract')],
        );
      }

      final json = jsonDecode(jsonMatch.group(0)!);
      final actions = (json['actions'] as List?)
              ?.map((a) => BrowserAction(
                    type: a['type'] ?? 'extract',
                    url: a['url'],
                    selector: a['selector'],
                    text: a['text'],
                    direction: a['direction'],
                    amount: a['amount'],
                    duration: a['duration'],
                    price: a['price'],
                    description: a['description'],
                    imageUrl: a['imageUrl'],
                  ))
              .toList() ??
          [];

      return AIPlan(
        explanation: json['explanation'] ?? 'Executing actions',
        actions: actions.isEmpty ? [BrowserAction(type: 'extract')] : actions,
      );
    } catch (e) {
      debugPrint('Error parsing AI plan: $e');
      return AIPlan(
        explanation: 'Reading current page',
        actions: [BrowserAction(type: 'extract')],
      );
    }
  }

  Future<String> _generateResponse({
    required String query,
    required String pageContent,
    required String url,
    List<String>? history,
  }) async {
    final historyText = history?.join('\n') ?? '';
    final prompt = '''
Based on the browsing session, answer the user's question.

USER QUESTION: $query

SESSION HISTORY:
$historyText

FINAL PAGE URL: $url

FINAL PAGE CONTENT:
$pageContent

Provide a helpful, detailed response based on the findings.
''';

    return await _callAI(prompt);
  }

  Future<String> generateComparisonTable() async {
    if (_collectedProducts.isEmpty) return "No products collected to compare.";

    final productsJson = _collectedProducts.map((p) => p.toJson()).toList();
    final prompt = '''
You are an expert shopping assistant. Create a detailed comparison table for the following products in Markdown format.

PRODUCTS:
${jsonEncode(productsJson)}

REQUIREMENTS:
1. Create a Markdown table.
2. Columns: Product Name, Price, Key Features, Pros, Cons.
3. Analyze the descriptions to infer Pros/Cons if not explicitly stated.
4. Add a "Recommendation" section below the table suggesting which one is best for different needs (e.g., "Best Value", "Best Overall").
''';

    return await _callAI(prompt);
  }

  Future<String> _callAI(String prompt) async {
    try {
      final settings = await AISettingsService.getSettings();
      final model = settings.model;

      if (model == null || model.isEmpty) {
        throw Exception('No AI model configured');
      }

      final apiService = ref.read(apiServiceProvider);
      final messages = [
        {'role': 'user', 'content': prompt}
      ];

      return await apiService
          .chatWithAI(
            messages: messages,
            provider: settings.provider,
            model: model,
          )
          .timeout(const Duration(minutes: 2));
    } catch (e) {
      debugPrint('AI Error: $e');
      if (e.toString().contains('no AI model')) {
        return 'I need an AI model to work. Please go to Settings > AI Models and select one.';
      }
      return 'Sorry, I encountered an error: $e';
    }
  }

  /// Navigate to URL
  Future<void> navigateTo(String url) async {
    if (_controller == null) return;

    String finalUrl = url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      finalUrl = 'https://$url';
    }

    await _controller!.loadRequest(Uri.parse(finalUrl));
  }

  /// Go back
  Future<void> goBack() async {
    if (_controller != null && await _controller!.canGoBack()) {
      await _controller!.goBack();
    }
  }

  /// Go forward
  Future<void> goForward() async {
    if (_controller != null && await _controller!.canGoForward()) {
      await _controller!.goForward();
    }
  }

  /// Refresh page
  Future<void> refresh() async {
    await _controller?.reload();
  }

  void dispose() {
    _statusController.close();
  }
}

class AIBrowserUpdate {
  final String status;
  final AIBrowserAction? action;
  final bool isComplete;
  final String? finalResponse;
  final String? currentUrl;
  final String? screenshotBase64;

  final bool isFinding;
  final String? findingText;

  // Product Discovery fields
  final bool isProduct;
  final String? productTitle;
  final String? productPrice;
  final String? productDescription;
  final String? productImageUrl;

  AIBrowserUpdate({
    required this.status,
    this.action,
    this.isComplete = false,
    this.finalResponse,
    this.currentUrl,
    this.screenshotBase64,
    this.isFinding = false,
    this.findingText,
    this.isProduct = false,
    this.productTitle,
    this.productPrice,
    this.productDescription,
    this.productImageUrl,
  });
}

enum AIBrowserAction {
  thinking,
  planning,
  navigating,
  takingScreenshot,
  clicking,
  typing,
  scrolling,
  waiting,
  extracting,
  complete,
  waitingForFeedback, // New status for product feedback
}

class AIPlan {
  final String explanation;
  final List<BrowserAction> actions;

  AIPlan({required this.explanation, required this.actions});
}

class BrowserAction {
  final String type;
  final String? url;
  final String? selector;
  final String? text;
  final String? direction;
  final int? amount;
  final int? duration;

  // Product data
  final String? price;
  final String? description;
  final String? imageUrl;

  BrowserAction({
    required this.type,
    this.url,
    this.selector,
    this.text,
    this.direction,
    this.amount,
    this.duration,
    this.price,
    this.description,
    this.imageUrl,
  });
}

final aiBrowserServiceProvider = Provider<AIBrowserService>((ref) {
  return AIBrowserService(ref);
});

/// Feedback data from user when reviewing a proposed product
class ProductFeedback {
  final bool liked;
  final Uint8List? screenshotBytes;

  ProductFeedback({
    required this.liked,
    this.screenshotBytes,
  });
}
