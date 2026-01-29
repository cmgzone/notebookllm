import axios, { type AxiosInstance, type AxiosRequestConfig, type AxiosResponse } from 'axios';
import pool from '../config/database.js';

export interface ShopifyCredentials {
  storeDomain: string;
  accessToken: string;
  apiVersion?: string;
}

export interface ShopifyShop {
  id: number;
  name: string;
  email?: string;
  domain?: string;
  myshopify_domain?: string;
  plan_name?: string;
}

export interface ShopifyConnectionTestResult {
  shop: ShopifyShop;
}

export interface ShopifyOrder {
  id: number;
  name?: string;
  created_at?: string;
  total_price?: string;
  currency?: string;
  financial_status?: string;
  fulfillment_status?: string | null;
  email?: string;
}

export interface ShopifyProduct {
  id: number;
  title?: string;
  status?: string;
  vendor?: string;
  product_type?: string;
  created_at?: string;
  updated_at?: string;
  tags?: string;
  variants?: Array<{
    id: number;
    title?: string;
    sku?: string;
    price?: string;
    inventory_item_id?: number;
    inventory_quantity?: number;
  }>;
}

export interface ShopifyInventoryLevel {
  inventory_item_id: number;
  location_id: number;
  available: number;
  updated_at?: string;
}

export interface ShopifyListResult<T> {
  items: T[];
  nextPageInfo?: string;
}

export interface ShopifyOrdersAnalytics {
  orderCount: number;
  grossSales: number;
  averageOrderValue: number;
  currency?: string;
}

function normalizeStoreBaseUrl(storeDomain: string): string {
  const trimmed = storeDomain.trim();
  if (trimmed.length === 0) {
    throw new Error('storeDomain is required');
  }

  const withScheme = /^https?:\/\//i.test(trimmed) ? trimmed : `https://${trimmed}`;
  return withScheme.replace(/\/+$/, '');
}

function getApiVersion(credentials: ShopifyCredentials): string {
  const v = (credentials.apiVersion || process.env.SHOPIFY_API_VERSION || '').trim();
  return v.length > 0 ? v : '2024-10';
}

function parseNextPageInfo(linkHeader: string | undefined): string | undefined {
  if (!linkHeader) return undefined;
  const parts = linkHeader.split(',').map((p) => p.trim());
  for (const part of parts) {
    const match = part.match(/<([^>]+)>\s*;\s*rel="([^"]+)"/i);
    if (!match) continue;
    const url = match[1];
    const rel = match[2];
    if (rel !== 'next') continue;
    try {
      const u = new URL(url);
      const pageInfo = u.searchParams.get('page_info');
      return pageInfo || undefined;
    } catch {
      return undefined;
    }
  }
  return undefined;
}

function parseMoney(value: unknown): number {
  if (typeof value === 'number') return Number.isFinite(value) ? value : 0;
  if (typeof value !== 'string') return 0;
  const n = Number.parseFloat(value);
  return Number.isFinite(n) ? n : 0;
}

class GituShopifyManager {
  private createClient(credentials: ShopifyCredentials): AxiosInstance {
    const baseUrl = normalizeStoreBaseUrl(credentials.storeDomain);
    const apiVersion = getApiVersion(credentials);

    if (!credentials.accessToken || credentials.accessToken.trim().length === 0) {
      throw new Error('accessToken is required');
    }

    return axios.create({
      baseURL: `${baseUrl}/admin/api/${apiVersion}`,
      timeout: 30000,
      headers: {
        'X-Shopify-Access-Token': credentials.accessToken,
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
    });
  }

  private async requestRaw<T>(
    credentials: ShopifyCredentials,
    config: AxiosRequestConfig
  ): Promise<AxiosResponse<T>> {
    const client = this.createClient(credentials);
    try {
      const res = await client.request<T>(config);
      return res;
    } catch (error: any) {
      const status = error?.response?.status;
      const data = error?.response?.data;
      const messageFromData =
        typeof data === 'string'
          ? data
          : data?.errors
              ? JSON.stringify(data.errors)
              : data?.error
                ? String(data.error)
                : data?.message
                  ? String(data.message)
                  : undefined;

      const statusPart = status ? ` (${status})` : '';
      const message = messageFromData ? `Shopify request failed${statusPart}: ${messageFromData}` : `Shopify request failed${statusPart}`;
      throw new Error(message);
    }
  }

  private async request<T>(
    credentials: ShopifyCredentials,
    config: AxiosRequestConfig
  ): Promise<T> {
    const res = await this.requestRaw<T>(credentials, config);
    return res.data;
  }

  async testConnection(credentials: ShopifyCredentials): Promise<ShopifyConnectionTestResult> {
    const data = await this.request<{ shop: ShopifyShop }>(credentials, {
      method: 'GET',
      url: '/shop.json',
    });
    return { shop: data.shop };
  }

  async listOrders(
    credentials: ShopifyCredentials,
    options?: {
      limit?: number;
      status?: 'open' | 'closed' | 'cancelled' | 'any';
      createdAtMin?: string;
      createdAtMax?: string;
      financialStatus?: string;
      fulfillmentStatus?: string;
      fields?: string;
      pageInfo?: string;
    }
  ): Promise<ShopifyListResult<ShopifyOrder>> {
    const res = await this.requestRaw<{ orders: ShopifyOrder[] }>(credentials, {
      method: 'GET',
      url: '/orders.json',
      params: {
        limit: options?.limit,
        status: options?.status || 'any',
        created_at_min: options?.createdAtMin,
        created_at_max: options?.createdAtMax,
        financial_status: options?.financialStatus,
        fulfillment_status: options?.fulfillmentStatus,
        fields: options?.fields,
        page_info: options?.pageInfo,
      },
    });

    return {
      items: res.data.orders || [],
      nextPageInfo: parseNextPageInfo(res.headers?.link as string | undefined),
    };
  }

  async listProducts(
    credentials: ShopifyCredentials,
    options?: {
      limit?: number;
      status?: 'active' | 'archived' | 'draft' | 'any';
      fields?: string;
      pageInfo?: string;
    }
  ): Promise<ShopifyListResult<ShopifyProduct>> {
    const res = await this.requestRaw<{ products: ShopifyProduct[] }>(credentials, {
      method: 'GET',
      url: '/products.json',
      params: {
        limit: options?.limit,
        status: options?.status || 'any',
        fields: options?.fields,
        page_info: options?.pageInfo,
      },
    });

    return {
      items: res.data.products || [],
      nextPageInfo: parseNextPageInfo(res.headers?.link as string | undefined),
    };
  }

  async createProduct(
    credentials: ShopifyCredentials,
    product: Omit<ShopifyProduct, 'id'>
  ): Promise<ShopifyProduct> {
    const data = await this.request<{ product: ShopifyProduct }>(credentials, {
      method: 'POST',
      url: '/products.json',
      data: { product },
    });
    return data.product;
  }

  async updateProduct(
    credentials: ShopifyCredentials,
    productId: number,
    product: Partial<Omit<ShopifyProduct, 'id'>>
  ): Promise<ShopifyProduct> {
    const data = await this.request<{ product: ShopifyProduct }>(credentials, {
      method: 'PUT',
      url: `/products/${productId}.json`,
      data: { product },
    });
    return data.product;
  }

  async deleteProduct(credentials: ShopifyCredentials, productId: number): Promise<void> {
    await this.request(credentials, {
      method: 'DELETE',
      url: `/products/${productId}.json`,
    });
  }

  async listInventoryLevels(
    credentials: ShopifyCredentials,
    options: {
      inventoryItemIds: number[];
      locationIds?: number[];
      limit?: number;
    }
  ): Promise<ShopifyInventoryLevel[]> {
    if (!options.inventoryItemIds || options.inventoryItemIds.length === 0) {
      throw new Error('inventoryItemIds is required');
    }

    const data = await this.request<{ inventory_levels: ShopifyInventoryLevel[] }>(credentials, {
      method: 'GET',
      url: '/inventory_levels.json',
      params: {
        inventory_item_ids: options.inventoryItemIds.join(','),
        location_ids: options.locationIds && options.locationIds.length > 0 ? options.locationIds.join(',') : undefined,
        limit: options.limit,
      },
    });
    return data.inventory_levels || [];
  }

  async adjustInventoryLevel(
    credentials: ShopifyCredentials,
    params: { inventoryItemId: number; locationId: number; availableAdjustment: number }
  ): Promise<ShopifyInventoryLevel> {
    const data = await this.request<{ inventory_level: ShopifyInventoryLevel }>(credentials, {
      method: 'POST',
      url: '/inventory_levels/adjust.json',
      data: {
        inventory_item_id: params.inventoryItemId,
        location_id: params.locationId,
        available_adjustment: params.availableAdjustment,
      },
    });
    return data.inventory_level;
  }

  async getOrdersAnalytics(
    credentials: ShopifyCredentials,
    options?: { createdAtMin?: string; createdAtMax?: string; maxPages?: number; limit?: number }
  ): Promise<ShopifyOrdersAnalytics> {
    const limit = options?.limit || 50;
    const maxPages = options?.maxPages || 10;
    let pageInfo: string | undefined;
    let pages = 0;

    let orderCount = 0;
    let grossSales = 0;
    let currency: string | undefined;

    do {
      const page = await this.listOrders(credentials, {
        limit,
        status: 'any',
        createdAtMin: options?.createdAtMin,
        createdAtMax: options?.createdAtMax,
        fields: 'id,total_price,currency',
        pageInfo,
      });

      for (const order of page.items) {
        orderCount += 1;
        grossSales += parseMoney(order.total_price);
        currency = currency || order.currency;
      }

      pageInfo = page.nextPageInfo;
      pages += 1;
    } while (pageInfo && pages < maxPages);

    const averageOrderValue = orderCount > 0 ? grossSales / orderCount : 0;
    return { orderCount, grossSales, averageOrderValue, currency };
  }

  async connect(userId: string, credentials: ShopifyCredentials, shopInfo?: any) {
    await pool.query(
      `INSERT INTO shopify_connections (user_id, store_domain, access_token, shop_name, shop_email, shop_plan, api_version)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       ON CONFLICT (user_id) DO UPDATE SET
         store_domain = $2,
         access_token = $3,
         shop_name = $4,
         shop_email = $5,
         shop_plan = $6,
         api_version = $7,
         updated_at = NOW()`,
      [
        userId,
        credentials.storeDomain,
        credentials.accessToken,
        shopInfo?.name,
        shopInfo?.email,
        shopInfo?.plan_name,
        credentials.apiVersion || '2024-10'
      ]
    );
  }

  async disconnect(userId: string) {
    await pool.query('DELETE FROM shopify_connections WHERE user_id = $1', [userId]);
  }

  async getConnection(userId: string): Promise<ShopifyCredentials | null> {
    const res = await pool.query('SELECT * FROM shopify_connections WHERE user_id = $1', [userId]);
    if (res.rows.length === 0) return null;
    const row = res.rows[0];
    return {
      storeDomain: row.store_domain,
      accessToken: row.access_token,
      apiVersion: row.api_version,
    };
  }

  async getConnectionDetails(userId: string) {
    const res = await pool.query('SELECT * FROM shopify_connections WHERE user_id = $1', [userId]);
    return res.rows[0] || null;
  }

  async isConnected(userId: string): Promise<boolean> {
    const conn = await this.getConnection(userId);
    return !!conn;
  }
}

export const gituShopifyManager = new GituShopifyManager();
export default gituShopifyManager;
