import { describe, it, expect } from '@jest/globals';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

describe('WhatsApp contacts search', () => {
  it('finds contacts by name and digits', async () => {
    const testFileDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..', '..');
    const contactsFile = path.join(testFileDir, 'whatsapp_contacts.json');

    const contacts = {
      '15550001234@s.whatsapp.net': { name: 'Alice Johnson', notify: 'Alice' },
      '15550009999@s.whatsapp.net': { verifiedName: 'Bob Builder' },
      '12345-67890@s.whatsapp.net': { pushName: 'Charlie' },
      'SomeGroup@g.us': { subject: 'Project Group' },
    };

    fs.writeFileSync(contactsFile, JSON.stringify(contacts, null, 2), 'utf-8');

    try {
      const { whatsappAdapter } = await import('../adapters/whatsappAdapter.js');

      const byName = await whatsappAdapter.searchContacts('alice');
      expect(byName.some(c => c.id === '15550001234@s.whatsapp.net')).toBe(true);

      const byDigits = await whatsappAdapter.searchContacts('+1 (555) 000-9999');
      expect(byDigits.some(c => c.id === '15550009999@s.whatsapp.net')).toBe(true);

      const byGroup = await whatsappAdapter.searchContacts('project');
      expect(byGroup.some(c => c.id === 'SomeGroup@g.us')).toBe(true);
    } finally {
      if (fs.existsSync(contactsFile)) fs.unlinkSync(contactsFile);
    }
  });
});
