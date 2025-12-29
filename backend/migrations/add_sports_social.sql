-- Sports Social & Community Tables Migration
-- Run this migration to add sports prediction tracking, leaderboards, and tipster features

-- Sports predictions table (user prediction history)
CREATE TABLE IF NOT EXISTS sports_predictions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    match_id TEXT NOT NULL,
    home_team TEXT NOT NULL,
    away_team TEXT NOT NULL,
    league TEXT,
    sport TEXT DEFAULT 'Football',
    prediction_type TEXT NOT NULL, -- 'home_win', 'away_win', 'draw', 'over', 'under', 'btts', etc.
    prediction_value TEXT, -- e.g., '2.5' for over/under
    odds DECIMAL(10,2),
    stake DECIMAL(10,2) DEFAULT 0,
    result TEXT, -- 'won', 'lost', 'pending', 'void'
    profit DECIMAL(10,2) DEFAULT 0,
    match_date TIMESTAMPTZ,
    is_public BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    settled_at TIMESTAMPTZ
);

-- User sports stats (for leaderboard)
CREATE TABLE IF NOT EXISTS sports_user_stats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    total_predictions INTEGER DEFAULT 0,
    wins INTEGER DEFAULT 0,
    losses INTEGER DEFAULT 0,
    pending INTEGER DEFAULT 0,
    win_rate DECIMAL(5,2) DEFAULT 0,
    total_stake DECIMAL(12,2) DEFAULT 0,
    total_profit DECIMAL(12,2) DEFAULT 0,
    roi DECIMAL(8,2) DEFAULT 0,
    current_streak INTEGER DEFAULT 0,
    best_streak INTEGER DEFAULT 0,
    rank INTEGER,
    badges JSONB DEFAULT '[]',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tipsters table (users who share predictions publicly)
CREATE TABLE IF NOT EXISTS sports_tipsters (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    username TEXT NOT NULL,
    bio TEXT,
    avatar_url TEXT,
    specialties JSONB DEFAULT '[]', -- ['Premier League', 'Over/Under', etc.]
    is_verified BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    followers_count INTEGER DEFAULT 0,
    total_tips INTEGER DEFAULT 0,
    win_rate DECIMAL(5,2) DEFAULT 0,
    roi DECIMAL(8,2) DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tipster followers (who follows whom)
CREATE TABLE IF NOT EXISTS sports_tipster_followers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tipster_id UUID NOT NULL REFERENCES sports_tipsters(id) ON DELETE CASCADE,
    follower_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tipster_id, follower_id)
);

-- Favorite teams
CREATE TABLE IF NOT EXISTS sports_favorite_teams (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    team_name TEXT NOT NULL,
    team_logo TEXT,
    league TEXT,
    sport TEXT DEFAULT 'Football',
    notifications_enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, team_name, league)
);

-- Bankroll entries (virtual betting tracker)
CREATE TABLE IF NOT EXISTS sports_bankroll (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    amount DECIMAL(12,2) NOT NULL,
    type TEXT NOT NULL, -- 'deposit', 'withdrawal', 'bet', 'win'
    description TEXT,
    balance_after DECIMAL(12,2) NOT NULL,
    prediction_id UUID REFERENCES sports_predictions(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Betting slips (saved multi-bet combinations)
CREATE TABLE IF NOT EXISTS sports_betting_slips (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name TEXT,
    selections JSONB NOT NULL, -- array of selections
    total_stake DECIMAL(10,2),
    total_odds DECIMAL(10,2),
    potential_win DECIMAL(12,2),
    slip_type TEXT DEFAULT 'accumulator', -- 'single', 'accumulator', 'system'
    status TEXT DEFAULT 'pending', -- 'pending', 'won', 'lost', 'partial'
    created_at TIMESTAMPTZ DEFAULT NOW(),
    settled_at TIMESTAMPTZ
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_sports_predictions_user ON sports_predictions(user_id);
CREATE INDEX IF NOT EXISTS idx_sports_predictions_result ON sports_predictions(result);
CREATE INDEX IF NOT EXISTS idx_sports_predictions_date ON sports_predictions(match_date);
CREATE INDEX IF NOT EXISTS idx_sports_user_stats_rank ON sports_user_stats(rank);
CREATE INDEX IF NOT EXISTS idx_sports_user_stats_roi ON sports_user_stats(roi DESC);
CREATE INDEX IF NOT EXISTS idx_sports_tipsters_verified ON sports_tipsters(is_verified, is_active);
CREATE INDEX IF NOT EXISTS idx_sports_tipster_followers_tipster ON sports_tipster_followers(tipster_id);
CREATE INDEX IF NOT EXISTS idx_sports_favorite_teams_user ON sports_favorite_teams(user_id);
CREATE INDEX IF NOT EXISTS idx_sports_bankroll_user ON sports_bankroll(user_id);
CREATE INDEX IF NOT EXISTS idx_sports_betting_slips_user ON sports_betting_slips(user_id);

-- Function to update user stats after prediction settlement
CREATE OR REPLACE FUNCTION update_sports_user_stats()
RETURNS TRIGGER AS $$
BEGIN
    -- Recalculate stats for the user
    INSERT INTO sports_user_stats (user_id, total_predictions, wins, losses, pending, win_rate, total_stake, total_profit, roi)
    SELECT 
        NEW.user_id,
        COUNT(*),
        COUNT(*) FILTER (WHERE result = 'won'),
        COUNT(*) FILTER (WHERE result = 'lost'),
        COUNT(*) FILTER (WHERE result = 'pending'),
        CASE WHEN COUNT(*) FILTER (WHERE result IN ('won', 'lost')) > 0 
            THEN (COUNT(*) FILTER (WHERE result = 'won')::DECIMAL / COUNT(*) FILTER (WHERE result IN ('won', 'lost')) * 100)
            ELSE 0 END,
        COALESCE(SUM(stake), 0),
        COALESCE(SUM(profit), 0),
        CASE WHEN COALESCE(SUM(stake), 0) > 0 
            THEN (COALESCE(SUM(profit), 0) / SUM(stake) * 100)
            ELSE 0 END
    FROM sports_predictions
    WHERE user_id = NEW.user_id
    ON CONFLICT (user_id) DO UPDATE SET
        total_predictions = EXCLUDED.total_predictions,
        wins = EXCLUDED.wins,
        losses = EXCLUDED.losses,
        pending = EXCLUDED.pending,
        win_rate = EXCLUDED.win_rate,
        total_stake = EXCLUDED.total_stake,
        total_profit = EXCLUDED.total_profit,
        roi = EXCLUDED.roi,
        updated_at = NOW();
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update stats
DROP TRIGGER IF EXISTS trigger_update_sports_stats ON sports_predictions;
CREATE TRIGGER trigger_update_sports_stats
    AFTER INSERT OR UPDATE ON sports_predictions
    FOR EACH ROW
    EXECUTE FUNCTION update_sports_user_stats();

-- Function to update leaderboard ranks
CREATE OR REPLACE FUNCTION update_sports_leaderboard_ranks()
RETURNS void AS $$
BEGIN
    WITH ranked AS (
        SELECT id, ROW_NUMBER() OVER (ORDER BY roi DESC, win_rate DESC, total_predictions DESC) as new_rank
        FROM sports_user_stats
        WHERE total_predictions >= 10 -- Minimum predictions to be ranked
    )
    UPDATE sports_user_stats s
    SET rank = r.new_rank
    FROM ranked r
    WHERE s.id = r.id;
END;
$$ LANGUAGE plpgsql;
