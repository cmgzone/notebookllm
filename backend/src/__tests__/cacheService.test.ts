import { describe, it, expect, beforeEach, jest } from '@jest/globals';

const mockRedisClient: any = {
  get: jest.fn(),
  setEx: jest.fn(),
  del: jest.fn(),
  scanIterator: jest.fn(),
};

jest.unstable_mockModule('../config/redis.js', () => {
  return {
    __esModule: true,
    default: mockRedisClient,
    safeRedisCommand: async <T>(command: () => Promise<T>, _fallback: T) => {
      return command();
    },
  };
});

let cacheService: typeof import('../services/cacheService.js');

describe('cacheService', () => {
  beforeEach(async () => {
    mockRedisClient.get.mockReset();
    mockRedisClient.setEx.mockReset();
    mockRedisClient.del.mockReset();
    mockRedisClient.scanIterator.mockReset();

    cacheService = await import('../services/cacheService.js');
  });

  it('getOrSetCache returns cached value without calling fn', async () => {
    mockRedisClient.get.mockResolvedValueOnce(JSON.stringify({ ok: true }));

    const fn = jest.fn(async () => ({ ok: false }));
    const value = await cacheService.getOrSetCache('k1', fn, cacheService.CacheTTL.SHORT);

    expect(value).toEqual({ ok: true });
    expect(fn).not.toHaveBeenCalled();
    expect(mockRedisClient.setEx).not.toHaveBeenCalled();
  });

  it('getOrSetCache stores computed value when cache miss', async () => {
    mockRedisClient.get.mockResolvedValueOnce(null);

    const fn = jest.fn(async () => ({ computed: 123 }));
    const value = await cacheService.getOrSetCache('k2', fn, 60);

    expect(value).toEqual({ computed: 123 });
    expect(fn).toHaveBeenCalledTimes(1);
    expect(mockRedisClient.setEx).toHaveBeenCalledTimes(1);
    expect(mockRedisClient.setEx).toHaveBeenCalledWith('k2', 60, JSON.stringify({ computed: 123 }));
  });

  it('deleteCachePattern scans keys and deletes them', async () => {
    mockRedisClient.scanIterator.mockReturnValueOnce(
      (async function* () {
        yield ['k:a', 'k:b'];
        yield ['k:c'];
      })()
    );

    mockRedisClient.del.mockResolvedValueOnce(3);

    const deleted = await cacheService.deleteCachePattern('k:*');

    expect(deleted).toBe(3);
    expect(mockRedisClient.del).toHaveBeenCalledWith(['k:a', 'k:b', 'k:c']);
  });

  it('clearUserAnalyticsCache clears user stats and activity caches', async () => {
    mockRedisClient.get.mockResolvedValue(null);
    mockRedisClient.scanIterator.mockReturnValueOnce(
      (async function* () {
        yield ['user:u1:activity:30'];
      })()
    );
    mockRedisClient.del.mockResolvedValueOnce(1).mockResolvedValueOnce(1);

    await cacheService.clearUserAnalyticsCache('u1');

    expect(mockRedisClient.del).toHaveBeenCalledWith(cacheService.CacheKeys.userStats('u1'));
    expect(mockRedisClient.del).toHaveBeenCalledWith(['user:u1:activity:30']);
  });
});
