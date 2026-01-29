/**
 * Unit tests for Terminal CLI Adapter
 * 
 * Tests the terminal adapter functionality including:
 * - Initialization
 * - Message handling
 * - Built-in commands
 * - Progress indicators
 * - Connection state
 */

import { jest } from '@jest/globals';
import { terminalAdapter } from '../adapters/terminalAdapter.js';

describe('Terminal Adapter', () => {
  describe('Initialization', () => {
    it('should not be initialized by default', () => {
      expect(terminalAdapter.isInitialized()).toBe(false);
    });

    it('should report disconnected state when not initialized', () => {
      expect(terminalAdapter.getConnectionState()).toBe('disconnected');
    });
  });

  describe('Connection State', () => {
    it('should return correct connection state', () => {
      const state = terminalAdapter.getConnectionState();
      expect(['connected', 'disconnected', 'error']).toContain(state);
    });
  });

  describe('Message Handler Registration', () => {
    it('should allow registering message handlers', () => {
      const handler = jest.fn<(message: any) => void>();
      expect(() => {
        terminalAdapter.onCommand(handler);
      }).not.toThrow();
    });
  });

  describe('Response Sending', () => {
    it('should allow sending responses', () => {
      // Mock console.log to capture output
      const consoleSpy = jest.spyOn(console, 'log').mockImplementation(() => {});
      
      terminalAdapter.sendResponse('Test message');
      
      expect(consoleSpy).toHaveBeenCalled();
      consoleSpy.mockRestore();
    });
  });

  describe('Progress Display', () => {
    it('should allow displaying progress', () => {
      // Mock console.log to capture output
      const consoleSpy = jest.spyOn(console, 'log').mockImplementation(() => {});
      
      terminalAdapter.displayProgress('Test task', 50);
      
      expect(consoleSpy).toHaveBeenCalled();
      consoleSpy.mockRestore();
    });

    it('should handle progress completion', () => {
      const consoleSpy = jest.spyOn(console, 'log').mockImplementation(() => {});
      
      terminalAdapter.displayProgress('Test task', 100);
      
      expect(consoleSpy).toHaveBeenCalled();
      consoleSpy.mockRestore();
    });
  });
});

describe('Terminal Adapter Interface Compliance', () => {
  it('should implement all required methods from design document', () => {
    // Check that all required methods exist
    expect(typeof terminalAdapter.initialize).toBe('function');
    expect(typeof terminalAdapter.startREPL).toBe('function');
    expect(typeof terminalAdapter.sendResponse).toBe('function');
    expect(typeof terminalAdapter.onCommand).toBe('function');
    expect(typeof terminalAdapter.displayProgress).toBe('function');
    expect(typeof terminalAdapter.getConnectionState).toBe('function');
    expect(typeof terminalAdapter.isInitialized).toBe('function');
  });

  it('should have correct method signatures', () => {
    // Verify initialize accepts config
    expect(terminalAdapter.initialize.length).toBe(1);
    
    // Verify startREPL takes no arguments
    expect(terminalAdapter.startREPL.length).toBe(0);
    
    // Verify sendResponse takes a message
    expect(terminalAdapter.sendResponse.length).toBe(1);
    
    // Verify onCommand takes a handler
    expect(terminalAdapter.onCommand.length).toBe(1);
    
    // Verify displayProgress takes task and progress
    expect(terminalAdapter.displayProgress.length).toBe(2);
  });
});
