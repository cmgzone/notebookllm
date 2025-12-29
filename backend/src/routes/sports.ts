import { Router, Request, Response } from 'express';
import pool from '../config/database.js';
import { authenticateToken } from '../middleware/auth.js';
import sportradarService from '../services/sportradarService.js';

const router = Router();

// All routes require authentication
router.use(authenticateToken);

// ============ LIVE DATA (SportRadar) ============

// Get live matches
router.get('/live', async (req: Request, res: Response) => {
    try {
        const matches = await sportradarService.getLiveMatches();
        res.json({ matches });
    } catch (error) {
        console.error('Error fetching live matches:', error);
        res.status(500).json({ error: 'Failed to fetch live matches' });
    }
});

// Get today's fixtures
router.get('/fixtures/today', async (req: Request, res: Response) => {
    try {
        const matches = await sportradarService.getTodayFixtures();
        res.json({ matches });
    } catch (error) {
        console.error('Error fetching fixtures:', error);
        res.status(500).json({ error: 'Failed to fetch fixtures' });
    }
});

// Get fixtures by date
router.get('/fixtures/:date', async (req: Request, res: Response) => {
    try {
        const { date } = req.params;
        const matches = await sportradarService.getFixturesByDate(date);
        res.json({ matches });
    } catch (error) {
        console.error('Error fetching fixtures:', error);
        res.status(500).json({ error: 'Failed to fetch fixtures' });
    }
});

// Get match details
router.get('/match/:id', async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const match = await sportradarService.getMatchDetails(id);
        if (!match) {
            return res.status(404).json({ error: 'Match not found' });
        }
        res.json({ match });
    } catch (error) {
        console.error('Error fetching match details:', error);
        res.status(500).json({ error: 'Failed to fetch match details' });
    }
});

// Get match odds
router.get('/match/:id/odds', async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const odds = await sportradarService.getMatchOdds(id);
        res.json({ odds });
    } catch (error) {
        console.error('Error fetching odds:', error);
        res.status(500).json({ error: 'Failed to fetch odds' });
    }
});

// Get head-to-head
router.get('/h2h/:team1/:team2', async (req: Request, res: Response) => {
    try {
        const { team1, team2 } = req.params;
        const h2h = await sportradarService.getHeadToHead(team1, team2);
        res.json({ h2h });
    } catch (error) {
        console.error('Error fetching H2H:', error);
        res.status(500).json({ error: 'Failed to fetch head-to-head' });
    }
});

// Get team form
router.get('/team/:id/form', async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const limit = parseInt(req.query.limit as string) || 5;
        const form = await sportradarService.getTeamForm(id, limit);
        res.json({ form });
    } catch (error) {
        console.error('Error fetching team form:', error);
        res.status(500).json({ error: 'Failed to fetch team form' });
    }
});

// Get league standings
router.get('/standings/:leagueId', async (req: Request, res: Response) => {
    try {
        const { leagueId } = req.params;
        const standings = await sportradarService.getStandings(leagueId);
        res.json({ standings });
    } catch (error) {
        console.error('Error fetching standings:', error);
        res.status(500).json({ error: 'Failed to fetch standings' });
    }
});

// Get team injuries
router.get('/team/:id/injuries', async (req: Request, res: Response) => {
    try {
        const { id } = req.params;
        const injuries = await sportradarService.getTeamInjuries(id);
        res.json({ injuries });
    } catch (error) {
        console.error('Error fetching injuries:', error);
        res.status(500).json({ error: 'Failed to fetch injuries' });
    }
});

// ============ PREDICTIONS ============

// Get user's prediction history
router.get('/predictions', async (req: Request, res: Response) => {
    try {
        const userId = (req as any).user.id;
        const { limit = 50, offset = 0, result } = req.query;

        let query = `
            SELECT * FROM sports_predictions 
            WHERE user_id = $1
        `;
        const params: any[] = [userId];

        if (result && result !== 'all') {
            query += ` AND result = $${params.length + 1}`;
            params.push(result);
        }

        query += ` ORDER BY created_at DESC LIMIT $${params.length + 1} OFFSET $${params.length + 2}`;
        params.push(limit, offset);

        const { rows } = await pool.query(query, params);
        res.json({ predictions: rows });
    } catch (error) {
        console.error('Error fetching predictions:', error);
        res.status(500).json({ error: 'Failed to fetch predictions' });
    }
});

// Create a new prediction
router.post('/predictions', async (req: Request, res: Response) => {
    try {
        const userId = (req as any).user.id;
        const {
            matchId, homeTeam, awayTeam, league, sport,
            predictionType, predictionValue, odds, stake, matchDate, isPublic
        } = req.body;

        const { rows } = await pool.query(`
            INSERT INTO sports_predictions 
            (user_id, match_id, home_team, away_team, league, sport, prediction_type, 
             prediction_value, odds, stake, match_date, is_public, result)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, 'pending')
            RETURNING *
        `, [userId, matchId, homeTeam, awayTeam, league, sport || 'Football',
            predictionType, predictionValue, odds, stake || 0, matchDate, isPublic ?? true]);

        res.json({ prediction: rows[0] });
    } catch (error) {
        console.error('Error creating prediction:', error);
        res.status(500).json({ error: 'Failed to create prediction' });
    }
});

// Settle a prediction (won/lost)
router.put('/predictions/:id/settle', async (req: Request, res: Response) => {
    try {
        const userId = (req as any).user.id;
        const { id } = req.params;
        const { result } = req.body; // 'won', 'lost', 'void'

        // Get the prediction first
        const { rows: [prediction] } = await pool.query(
            'SELECT * FROM sports_predictions WHERE id = $1 AND user_id = $2',
            [id, userId]
        );

        if (!prediction) {
            return res.status(404).json({ error: 'Prediction not found' });
        }

        // Calculate profit
        let profit = 0;
        if (result === 'won') {
            profit = (prediction.odds - 1) * prediction.stake;
        } else if (result === 'lost') {
            profit = -prediction.stake;
        }

        const { rows } = await pool.query(`
            UPDATE sports_predictions 
            SET result = $1, profit = $2, settled_at = NOW()
            WHERE id = $3 AND user_id = $4
            RETURNING *
        `, [result, profit, id, userId]);

        res.json({ prediction: rows[0] });
    } catch (error) {
        console.error('Error settling prediction:', error);
        res.status(500).json({ error: 'Failed to settle prediction' });
    }
});

// ============ USER STATS & LEADERBOARD ============

// Get user's sports stats
router.get('/stats', async (req: Request, res: Response) => {
    try {
        const userId = (req as any).user.id;

        const { rows } = await pool.query(`
            SELECT * FROM sports_user_stats WHERE user_id = $1
        `, [userId]);

        if (rows.length === 0) {
            // Create initial stats
            const { rows: newStats } = await pool.query(`
                INSERT INTO sports_user_stats (user_id) VALUES ($1) RETURNING *
            `, [userId]);
            return res.json({ stats: newStats[0] });
        }

        res.json({ stats: rows[0] });
    } catch (error) {
        console.error('Error fetching stats:', error);
        res.status(500).json({ error: 'Failed to fetch stats' });
    }
});

// Get leaderboard
router.get('/leaderboard', async (req: Request, res: Response) => {
    try {
        const { timeframe = 'all', limit = 50 } = req.query;

        // For now, we use all-time stats. Timeframe filtering can be added later.
        const { rows } = await pool.query(`
            SELECT 
                s.*,
                u.display_name,
                u.avatar_url
            FROM sports_user_stats s
            JOIN users u ON s.user_id = u.id
            WHERE s.total_predictions >= 5
            ORDER BY s.roi DESC, s.win_rate DESC
            LIMIT $1
        `, [limit]);

        // Add rank
        const entries = rows.map((row, index) => ({
            ...row,
            rank: index + 1
        }));

        res.json({ leaderboard: entries });
    } catch (error) {
        console.error('Error fetching leaderboard:', error);
        res.status(500).json({ error: 'Failed to fetch leaderboard' });
    }
});

// ============ TIPSTERS ============

// Get all tipsters
router.get('/tipsters', async (req: Request, res: Response) => {
    try {
        const userId = (req as any).user.id;

        const { rows } = await pool.query(`
            SELECT 
                t.*,
                EXISTS(
                    SELECT 1 FROM sports_tipster_followers f 
                    WHERE f.tipster_id = t.id AND f.follower_id = $1
                ) as is_following
            FROM sports_tipsters t
            WHERE t.is_active = true
            ORDER BY t.followers_count DESC, t.roi DESC
        `, [userId]);

        res.json({ tipsters: rows });
    } catch (error) {
        console.error('Error fetching tipsters:', error);
        res.status(500).json({ error: 'Failed to fetch tipsters' });
    }
});

// Register as tipster
router.post('/tipsters/register', async (req: Request, res: Response) => {
    try {
        const userId = (req as any).user.id;
        const { username, bio, specialties } = req.body;

        // Check if already a tipster
        const existing = await pool.query(
            'SELECT id FROM sports_tipsters WHERE user_id = $1',
            [userId]
        );

        if (existing.rows.length > 0) {
            return res.status(400).json({ error: 'Already registered as tipster' });
        }

        const { rows } = await pool.query(`
            INSERT INTO sports_tipsters (user_id, username, bio, specialties)
            VALUES ($1, $2, $3, $4)
            RETURNING *
        `, [userId, username, bio, specialties || []]);

        res.json({ tipster: rows[0] });
    } catch (error) {
        console.error('Error registering tipster:', error);
        res.status(500).json({ error: 'Failed to register as tipster' });
    }
});

// Follow a tipster
router.post('/tipsters/:id/follow', async (req: Request, res: Response) => {
    try {
        const userId = (req as any).user.id;
        const tipsterId = req.params.id;

        await pool.query(`
            INSERT INTO sports_tipster_followers (tipster_id, follower_id)
            VALUES ($1, $2)
            ON CONFLICT DO NOTHING
        `, [tipsterId, userId]);

        // Update follower count
        await pool.query(`
            UPDATE sports_tipsters 
            SET followers_count = (
                SELECT COUNT(*) FROM sports_tipster_followers WHERE tipster_id = $1
            )
            WHERE id = $1
        `, [tipsterId]);

        res.json({ success: true });
    } catch (error) {
        console.error('Error following tipster:', error);
        res.status(500).json({ error: 'Failed to follow tipster' });
    }
});

// Unfollow a tipster
router.delete('/tipsters/:id/follow', async (req: Request, res: Response) => {
    try {
        const userId = (req as any).user.id;
        const tipsterId = req.params.id;

        await pool.query(`
            DELETE FROM sports_tipster_followers 
            WHERE tipster_id = $1 AND follower_id = $2
        `, [tipsterId, userId]);

        // Update follower count
        await pool.query(`
            UPDATE sports_tipsters 
            SET followers_count = (
                SELECT COUNT(*) FROM sports_tipster_followers WHERE tipster_id = $1
            )
            WHERE id = $1
        `, [tipsterId]);

        res.json({ success: true });
    } catch (error) {
        console.error('Error unfollowing tipster:', error);
        res.status(500).json({ error: 'Failed to unfollow tipster' });
    }
});

// Get tipsters I follow
router.get('/tipsters/following', async (req: Request, res: Response) => {
    try {
        const userId = (req as any).user.id;

        const { rows } = await pool.query(`
            SELECT t.*, true as is_following
            FROM sports_tipsters t
            JOIN sports_tipster_followers f ON t.id = f.tipster_id
            WHERE f.follower_id = $1
            ORDER BY t.roi DESC
        `, [userId]);

        res.json({ tipsters: rows });
    } catch (error) {
        console.error('Error fetching following:', error);
        res.status(500).json({ error: 'Failed to fetch following tipsters' });
    }
});

// ============ FAVORITES ============

// Get favorite teams
router.get('/favorites', async (req: Request, res: Response) => {
    try {
        const userId = (req as any).user.id;

        const { rows } = await pool.query(`
            SELECT * FROM sports_favorite_teams 
            WHERE user_id = $1
            ORDER BY created_at DESC
        `, [userId]);

        res.json({ favorites: rows });
    } catch (error) {
        console.error('Error fetching favorites:', error);
        res.status(500).json({ error: 'Failed to fetch favorites' });
    }
});

// Add favorite team
router.post('/favorites', async (req: Request, res: Response) => {
    try {
        const userId = (req as any).user.id;
        const { teamName, teamLogo, league, sport, notificationsEnabled } = req.body;

        const { rows } = await pool.query(`
            INSERT INTO sports_favorite_teams 
            (user_id, team_name, team_logo, league, sport, notifications_enabled)
            VALUES ($1, $2, $3, $4, $5, $6)
            ON CONFLICT (user_id, team_name, league) DO UPDATE SET
                team_logo = EXCLUDED.team_logo,
                notifications_enabled = EXCLUDED.notifications_enabled
            RETURNING *
        `, [userId, teamName, teamLogo, league, sport || 'Football', notificationsEnabled ?? true]);

        res.json({ favorite: rows[0] });
    } catch (error) {
        console.error('Error adding favorite:', error);
        res.status(500).json({ error: 'Failed to add favorite' });
    }
});

// Remove favorite team
router.delete('/favorites/:id', async (req: Request, res: Response) => {
    try {
        const userId = (req as any).user.id;
        const { id } = req.params;

        await pool.query(`
            DELETE FROM sports_favorite_teams 
            WHERE id = $1 AND user_id = $2
        `, [id, userId]);

        res.json({ success: true });
    } catch (error) {
        console.error('Error removing favorite:', error);
        res.status(500).json({ error: 'Failed to remove favorite' });
    }
});

// ============ BANKROLL ============

// Get bankroll history
router.get('/bankroll', async (req: Request, res: Response) => {
    try {
        const userId = (req as any).user.id;
        const { limit = 50 } = req.query;

        const { rows } = await pool.query(`
            SELECT * FROM sports_bankroll 
            WHERE user_id = $1
            ORDER BY created_at DESC
            LIMIT $2
        `, [userId, limit]);

        // Get current balance
        const { rows: balanceRows } = await pool.query(`
            SELECT balance_after FROM sports_bankroll 
            WHERE user_id = $1
            ORDER BY created_at DESC
            LIMIT 1
        `, [userId]);

        const currentBalance = balanceRows[0]?.balance_after || 0;

        res.json({ entries: rows, currentBalance });
    } catch (error) {
        console.error('Error fetching bankroll:', error);
        res.status(500).json({ error: 'Failed to fetch bankroll' });
    }
});

// Add bankroll entry
router.post('/bankroll', async (req: Request, res: Response) => {
    try {
        const userId = (req as any).user.id;
        const { amount, type, description, predictionId } = req.body;

        // Get current balance
        const { rows: balanceRows } = await pool.query(`
            SELECT balance_after FROM sports_bankroll 
            WHERE user_id = $1
            ORDER BY created_at DESC
            LIMIT 1
        `, [userId]);

        const currentBalance = parseFloat(balanceRows[0]?.balance_after || '0');
        const newBalance = currentBalance + parseFloat(amount);

        const { rows } = await pool.query(`
            INSERT INTO sports_bankroll 
            (user_id, amount, type, description, balance_after, prediction_id)
            VALUES ($1, $2, $3, $4, $5, $6)
            RETURNING *
        `, [userId, amount, type, description, newBalance, predictionId]);

        res.json({ entry: rows[0], currentBalance: newBalance });
    } catch (error) {
        console.error('Error adding bankroll entry:', error);
        res.status(500).json({ error: 'Failed to add bankroll entry' });
    }
});

// ============ BETTING SLIPS ============

// Get saved betting slips
router.get('/slips', async (req: Request, res: Response) => {
    try {
        const userId = (req as any).user.id;

        const { rows } = await pool.query(`
            SELECT * FROM sports_betting_slips 
            WHERE user_id = $1
            ORDER BY created_at DESC
        `, [userId]);

        res.json({ slips: rows });
    } catch (error) {
        console.error('Error fetching slips:', error);
        res.status(500).json({ error: 'Failed to fetch betting slips' });
    }
});

// Save betting slip
router.post('/slips', async (req: Request, res: Response) => {
    try {
        const userId = (req as any).user.id;
        const { name, selections, totalStake, totalOdds, potentialWin, slipType } = req.body;

        const { rows } = await pool.query(`
            INSERT INTO sports_betting_slips 
            (user_id, name, selections, total_stake, total_odds, potential_win, slip_type)
            VALUES ($1, $2, $3, $4, $5, $6, $7)
            RETURNING *
        `, [userId, name, JSON.stringify(selections), totalStake, totalOdds, potentialWin, slipType || 'accumulator']);

        res.json({ slip: rows[0] });
    } catch (error) {
        console.error('Error saving slip:', error);
        res.status(500).json({ error: 'Failed to save betting slip' });
    }
});

// Delete betting slip
router.delete('/slips/:id', async (req: Request, res: Response) => {
    try {
        const userId = (req as any).user.id;
        const { id } = req.params;

        await pool.query(`
            DELETE FROM sports_betting_slips 
            WHERE id = $1 AND user_id = $2
        `, [id, userId]);

        res.json({ success: true });
    } catch (error) {
        console.error('Error deleting slip:', error);
        res.status(500).json({ error: 'Failed to delete betting slip' });
    }
});

export default router;
