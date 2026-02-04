/**
 * Test script for Gitu Task Scheduler and Natural Language Parser
 */

import { gituTaskParser } from '../services/gituTaskParser.js';
import { gituTaskScheduler } from '../services/gituTaskScheduler.js';

console.log('🧪 Testing Gitu Task Scheduler\n');

// Test cases
const testCases = [
  'remind me tomorrow at 3pm to call John',
  'remind me in 30 minutes about the meeting',
  'every Monday at 9am send me a summary',
  'every day at 8pm remind me to exercise',
  'every 30 minutes remind me to drink water',
  'every hour check my emails',
  'schedule a meeting reminder for tomorrow at 2pm',
  'schedule email summary for next Monday at 10am',
];

console.log('📝 Testing Natural Language Parser:\n');

for (const testCase of testCases) {
  console.log(`Input: "${testCase}"`);
  const result = gituTaskParser.parse(testCase, 'test-user-id');
  
  if (result.success) {
    console.log(`✅ Success (confidence: ${result.confidence})`);
    console.log(`   Name: ${result.task?.name}`);
    console.log(`   Trigger: ${JSON.stringify(result.task?.trigger)}`);
    console.log(`   Action: ${JSON.stringify(result.task?.action)}`);
  } else {
    console.log(`❌ Failed: ${result.error}`);
  }
  console.log('');
}

console.log('\n📋 Supported Examples:');
gituTaskParser.getExamples().forEach((example, i) => {
  console.log(`${i + 1}. ${example}`);
});

console.log('\n✅ Parser test complete!');
console.log('\n💡 To test the full scheduler:');
console.log('1. Start the backend: npm start');
console.log('2. Create a task via API:');
console.log('   POST /api/gitu/tasks/parse');
console.log('   Body: {"text": "remind me in 2 minutes to test"}');
console.log('3. Wait for the scheduled time');
console.log('4. Check execution history:');
console.log('   GET /api/gitu/tasks/:id/executions');
