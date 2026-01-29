import http from 'http';
import { gituShopifyManager } from '../services/gituShopifyManager.js';

describe('GituShopifyManager', () => {
  let server: http.Server;
  let port: number;
  let lastRequest: { url?: string; token?: string; method?: string; body?: any; headers?: Record<string, any> } = {};

  beforeAll(async () => {
    server = http.createServer((req, res) => {
      const chunks: Buffer[] = [];
      req.on('data', (c) => chunks.push(Buffer.isBuffer(c) ? c : Buffer.from(c)));
      req.on('end', () => {
        const rawBody = Buffer.concat(chunks).toString('utf8');
        const parsedBody = rawBody.length > 0 ? (() => { try { return JSON.parse(rawBody); } catch { return rawBody; } })() : undefined;
        lastRequest = {
          url: req.url || undefined,
          method: req.method || undefined,
          token: (req.headers['x-shopify-access-token'] as string | undefined) || undefined,
          body: parsedBody,
          headers: req.headers as any,
        };

        const url = new URL(req.url || '/', `http://127.0.0.1:${port}`);
        const path = url.pathname;
        const token = lastRequest.token;

        if (path === '/admin/api/2024-10/shop.json' && token === 'test-access-token' && req.method === 'GET') {
          res.statusCode = 200;
          res.setHeader('Content-Type', 'application/json');
          res.end(JSON.stringify({ shop: { id: 1, name: 'Test Shop', domain: '127.0.0.1' } }));
          return;
        }

        if (path === '/admin/api/2024-10/orders.json' && token === 'test-access-token' && req.method === 'GET') {
          const pageInfo = url.searchParams.get('page_info');
          res.statusCode = 200;
          res.setHeader('Content-Type', 'application/json');
          if (!pageInfo) {
            res.setHeader(
              'Link',
              `<http://127.0.0.1:${port}/admin/api/2024-10/orders.json?limit=2&page_info=next>; rel="next"`
            );
            res.end(JSON.stringify({ orders: [
              { id: 101, total_price: '10.00', currency: 'USD' },
              { id: 102, total_price: '15.00', currency: 'USD' },
            ] }));
            return;
          }
          if (pageInfo === 'next') {
            res.end(JSON.stringify({ orders: [{ id: 103, total_price: '5.00', currency: 'USD' }] }));
            return;
          }
        }

        if (path === '/admin/api/2024-10/products.json' && token === 'test-access-token' && req.method === 'GET') {
          res.statusCode = 200;
          res.setHeader('Content-Type', 'application/json');
          res.end(JSON.stringify({ products: [{ id: 301, title: 'Prod A' }] }));
          return;
        }

        if (path === '/admin/api/2024-10/products.json' && token === 'test-access-token' && req.method === 'POST') {
          res.statusCode = 201;
          res.setHeader('Content-Type', 'application/json');
          res.end(JSON.stringify({ product: { id: 302, ...(lastRequest.body?.product || {}) } }));
          return;
        }

        if (path === '/admin/api/2024-10/products/302.json' && token === 'test-access-token' && req.method === 'PUT') {
          res.statusCode = 200;
          res.setHeader('Content-Type', 'application/json');
          res.end(JSON.stringify({ product: { id: 302, ...(lastRequest.body?.product || {}) } }));
          return;
        }

        if (path === '/admin/api/2024-10/products/302.json' && token === 'test-access-token' && req.method === 'DELETE') {
          res.statusCode = 200;
          res.setHeader('Content-Type', 'application/json');
          res.end(JSON.stringify({}));
          return;
        }

        if (path === '/admin/api/2024-10/inventory_levels.json' && token === 'test-access-token' && req.method === 'GET') {
          res.statusCode = 200;
          res.setHeader('Content-Type', 'application/json');
          res.end(JSON.stringify({
            inventory_levels: [
              { inventory_item_id: 200, location_id: 1, available: 5 },
            ],
          }));
          return;
        }

        if (path === '/admin/api/2024-10/inventory_levels/adjust.json' && token === 'test-access-token' && req.method === 'POST') {
          res.statusCode = 200;
          res.setHeader('Content-Type', 'application/json');
          res.end(JSON.stringify({
            inventory_level: {
              inventory_item_id: lastRequest.body?.inventory_item_id,
              location_id: lastRequest.body?.location_id,
              available: lastRequest.body?.available_adjustment,
            },
          }));
          return;
        }

        res.statusCode = 401;
        res.setHeader('Content-Type', 'application/json');
        res.end(JSON.stringify({ error: 'Unauthorized' }));
      });
    });

    await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
    const address = server.address();
    if (!address || typeof address === 'string') throw new Error('failed to bind server');
    port = address.port;
  });

  afterAll(async () => {
    await new Promise<void>((resolve) => server.close(() => resolve()));
  });

  test('testConnection calls Shopify shop endpoint with token header', async () => {
    const result = await gituShopifyManager.testConnection({
      storeDomain: `http://127.0.0.1:${port}`,
      accessToken: 'test-access-token',
      apiVersion: '2024-10',
    });

    expect(lastRequest.url).toBe('/admin/api/2024-10/shop.json');
    expect(lastRequest.token).toBe('test-access-token');
    expect(result.shop.name).toBe('Test Shop');
  });

  test('listOrders returns nextPageInfo from Link header', async () => {
    const first = await gituShopifyManager.listOrders({
      storeDomain: `http://127.0.0.1:${port}`,
      accessToken: 'test-access-token',
      apiVersion: '2024-10',
    }, { limit: 2 });

    expect(first.items).toHaveLength(2);
    expect(first.nextPageInfo).toBe('next');
    expect(lastRequest.method).toBe('GET');
    expect(lastRequest.token).toBe('test-access-token');
  });

  test('getOrdersAnalytics aggregates paginated order totals', async () => {
    const analytics = await gituShopifyManager.getOrdersAnalytics({
      storeDomain: `http://127.0.0.1:${port}`,
      accessToken: 'test-access-token',
      apiVersion: '2024-10',
    }, { limit: 2, maxPages: 5 });

    expect(analytics.orderCount).toBe(3);
    expect(analytics.grossSales).toBe(30);
    expect(analytics.averageOrderValue).toBe(10);
    expect(analytics.currency).toBe('USD');
  });

  test('product management and inventory endpoints send token and JSON payloads', async () => {
    const created = await gituShopifyManager.createProduct({
      storeDomain: `http://127.0.0.1:${port}`,
      accessToken: 'test-access-token',
      apiVersion: '2024-10',
    }, { title: 'New Product', status: 'active' });

    expect(created.id).toBe(302);
    expect(lastRequest.method).toBe('POST');
    expect(lastRequest.url).toBe('/admin/api/2024-10/products.json');
    expect(lastRequest.body?.product?.title).toBe('New Product');

    const updated = await gituShopifyManager.updateProduct({
      storeDomain: `http://127.0.0.1:${port}`,
      accessToken: 'test-access-token',
      apiVersion: '2024-10',
    }, 302, { title: 'Updated Product' });

    expect(updated.title).toBe('Updated Product');
    expect(lastRequest.method).toBe('PUT');

    const products = await gituShopifyManager.listProducts({
      storeDomain: `http://127.0.0.1:${port}`,
      accessToken: 'test-access-token',
      apiVersion: '2024-10',
    }, { limit: 10 });

    expect(products.items[0].id).toBe(301);
    expect(lastRequest.method).toBe('GET');

    const levels = await gituShopifyManager.listInventoryLevels({
      storeDomain: `http://127.0.0.1:${port}`,
      accessToken: 'test-access-token',
      apiVersion: '2024-10',
    }, { inventoryItemIds: [200], locationIds: [1] });

    expect(levels[0].available).toBe(5);
    expect(lastRequest.method).toBe('GET');

    const adjusted = await gituShopifyManager.adjustInventoryLevel({
      storeDomain: `http://127.0.0.1:${port}`,
      accessToken: 'test-access-token',
      apiVersion: '2024-10',
    }, { inventoryItemId: 200, locationId: 1, availableAdjustment: 2 });

    expect(adjusted.available).toBe(2);
    expect(lastRequest.method).toBe('POST');

    await gituShopifyManager.deleteProduct({
      storeDomain: `http://127.0.0.1:${port}`,
      accessToken: 'test-access-token',
      apiVersion: '2024-10',
    }, 302);

    expect(lastRequest.method).toBe('DELETE');
  });
});
