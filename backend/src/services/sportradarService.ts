/**
 * SportRadar API Service
 * Provides live scores, fixtures, team stats, head-to-head, and more
 * 
 * API Documentation: https://developer.sportradar.com/
 * 
 * Required ENV: SPORTRADAR_API_KEY
 */

import axios, { AxiosInstance } from 'axios';

// SportRadar API base URLs
const SOCCER_API_BASE = 'https://api.sportradar.com/soccer/trial/v4/en';
const ODDS_API_BASE = 'https://api.sportradar.com/oddscomparison-roweb/trial/v2/en';

interface SportRadarConfig {
    apiKey: string;
    format?: 'json' | 'xml';
}

interface Match {
    id: string;
    homeTeam: string;
    awayTeam: string;
    homeTeamLogo?: string;
    awayTeamLogo?: string;
    homeScore: number;
    awayScore: number;
    status: 'scheduled' | 'live' | 'finished' | 'postponed' | 'cancelled';
    minute?: string;
    league: string;
    leagueId: string;
    sport: string;
    kickoff: Date;
    venue?: string;
    events?: MatchEvent[];
    odds?: MatchOdds;
}

interface MatchEvent {
    type: string;
    team: string;
    player?: string;
    minute: string;
    description?: string;
}

interface MatchOdds {
    homeWin: number;
    draw: number;
    awayWin: number;
    over25?: number;
    under25?: number;
    btts?: number;
}

interface TeamStats {
    teamId: string;
    teamName: string;
    logo?: string;
    played: number;
    wins: number;
    draws: number;
    losses: number;
    goalsFor: number;
    goalsAgainst: number;
    points: number;
    position: number;
    form: string[];
}

interface HeadToHead {
    team1: string;
    team2: string;
    team1Wins: number;
    team2Wins: number;
    draws: number;
    team1Goals: number;
    team2Goals: number;
    matches: H2HMatch[];
}

interface H2HMatch {
    date: Date;
    competition: string;
    team1Score: number;
    team2Score: number;
    venue: string;
}

interface PlayerInjury {
    playerName: string;
    position: string;
    injuryType: string;
    status: 'out' | 'doubtful' | 'questionable';
    expectedReturn?: string;
}

class SportRadarService {
    private apiKey: string;
    private soccerClient: AxiosInstance;
    private oddsClient: AxiosInstance;
    private cache: Map<string, { data: any; expiry: number }> = new Map();
    private cacheTTL = 60000; // 1 minute cache

    constructor(config?: SportRadarConfig) {
        this.apiKey = config?.apiKey || process.env.SPORTRADAR_API_KEY || '';
        
        this.soccerClient = axios.create({
            baseURL: SOCCER_API_BASE,
            params: { api_key: this.apiKey },
            timeout: 10000,
        });

        this.oddsClient = axios.create({
            baseURL: ODDS_API_BASE,
            params: { api_key: this.apiKey },
            timeout: 10000,
        });
    }

    private getCached<T>(key: string): T | null {
        const cached = this.cache.get(key);
        if (cached && cached.expiry > Date.now()) {
            return cached.data as T;
        }
        this.cache.delete(key);
        return null;
    }

    private setCache(key: string, data: any, ttl?: number): void {
        this.cache.set(key, {
            data,
            expiry: Date.now() + (ttl || this.cacheTTL),
        });
    }

    /**
     * Get live matches across all competitions
     */
    async getLiveMatches(): Promise<Match[]> {
        const cacheKey = 'live_matches';
        const cached = this.getCached<Match[]>(cacheKey);
        if (cached) return cached;

        try {
            // SportRadar live endpoint
            const response = await this.soccerClient.get('/schedules/live/schedules.json');
            const matches = this.transformMatches(response.data?.sport_events || []);
            this.setCache(cacheKey, matches, 30000); // 30 second cache for live
            return matches;
        } catch (error) {
            console.error('SportRadar getLiveMatches error:', error);
            return this.getFallbackLiveMatches();
        }
    }

    /**
     * Get today's fixtures
     */
    async getTodayFixtures(): Promise<Match[]> {
        const cacheKey = 'today_fixtures';
        const cached = this.getCached<Match[]>(cacheKey);
        if (cached) return cached;

        try {
            const today = new Date().toISOString().split('T')[0];
            const response = await this.soccerClient.get(`/schedules/${today}/schedules.json`);
            const matches = this.transformMatches(response.data?.sport_events || []);
            this.setCache(cacheKey, matches, 300000); // 5 minute cache
            return matches;
        } catch (error) {
            console.error('SportRadar getTodayFixtures error:', error);
            return this.getFallbackFixtures();
        }
    }

    /**
     * Get fixtures for a specific date
     */
    async getFixturesByDate(date: string): Promise<Match[]> {
        const cacheKey = `fixtures_${date}`;
        const cached = this.getCached<Match[]>(cacheKey);
        if (cached) return cached;

        try {
            const response = await this.soccerClient.get(`/schedules/${date}/schedules.json`);
            const matches = this.transformMatches(response.data?.sport_events || []);
            this.setCache(cacheKey, matches, 300000);
            return matches;
        } catch (error) {
            console.error('SportRadar getFixturesByDate error:', error);
            return [];
        }
    }

    /**
     * Get match details with timeline
     */
    async getMatchDetails(matchId: string): Promise<Match | null> {
        const cacheKey = `match_${matchId}`;
        const cached = this.getCached<Match>(cacheKey);
        if (cached) return cached;

        try {
            const response = await this.soccerClient.get(`/sport_events/${matchId}/timeline.json`);
            const match = this.transformMatchDetails(response.data);
            this.setCache(cacheKey, match, 30000);
            return match;
        } catch (error) {
            console.error('SportRadar getMatchDetails error:', error);
            return null;
        }
    }

    /**
     * Get head-to-head stats between two teams
     */
    async getHeadToHead(team1Id: string, team2Id: string): Promise<HeadToHead | null> {
        const cacheKey = `h2h_${team1Id}_${team2Id}`;
        const cached = this.getCached<HeadToHead>(cacheKey);
        if (cached) return cached;

        try {
            const response = await this.soccerClient.get(
                `/competitors/${team1Id}/versus/${team2Id}/summaries.json`
            );
            const h2h = this.transformH2H(response.data, team1Id, team2Id);
            this.setCache(cacheKey, h2h, 3600000); // 1 hour cache
            return h2h;
        } catch (error) {
            console.error('SportRadar getHeadToHead error:', error);
            return this.getFallbackH2H(team1Id, team2Id);
        }
    }

    /**
     * Get team form (last N matches)
     */
    async getTeamForm(teamId: string, limit: number = 5): Promise<TeamStats | null> {
        const cacheKey = `form_${teamId}_${limit}`;
        const cached = this.getCached<TeamStats>(cacheKey);
        if (cached) return cached;

        try {
            const response = await this.soccerClient.get(`/competitors/${teamId}/summaries.json`);
            const form = this.transformTeamForm(response.data, limit);
            this.setCache(cacheKey, form, 3600000);
            return form;
        } catch (error) {
            console.error('SportRadar getTeamForm error:', error);
            return null;
        }
    }

    /**
     * Get league standings
     */
    async getStandings(leagueId: string): Promise<TeamStats[]> {
        const cacheKey = `standings_${leagueId}`;
        const cached = this.getCached<TeamStats[]>(cacheKey);
        if (cached) return cached;

        try {
            const response = await this.soccerClient.get(`/competitions/${leagueId}/standings.json`);
            const standings = this.transformStandings(response.data);
            this.setCache(cacheKey, standings, 3600000);
            return standings;
        } catch (error) {
            console.error('SportRadar getStandings error:', error);
            return [];
        }
    }

    /**
     * Get team injuries
     */
    async getTeamInjuries(teamId: string): Promise<PlayerInjury[]> {
        const cacheKey = `injuries_${teamId}`;
        const cached = this.getCached<PlayerInjury[]>(cacheKey);
        if (cached) return cached;

        try {
            const response = await this.soccerClient.get(`/competitors/${teamId}/profile.json`);
            const injuries = this.transformInjuries(response.data);
            this.setCache(cacheKey, injuries, 3600000);
            return injuries;
        } catch (error) {
            console.error('SportRadar getTeamInjuries error:', error);
            return this.getFallbackInjuries();
        }
    }

    /**
     * Get odds for a match
     */
    async getMatchOdds(matchId: string): Promise<MatchOdds | null> {
        const cacheKey = `odds_${matchId}`;
        const cached = this.getCached<MatchOdds>(cacheKey);
        if (cached) return cached;

        try {
            const response = await this.oddsClient.get(`/sport_events/${matchId}/markets.json`);
            const odds = this.transformOdds(response.data);
            this.setCache(cacheKey, odds, 60000); // 1 minute cache for odds
            return odds;
        } catch (error) {
            console.error('SportRadar getMatchOdds error:', error);
            return this.getFallbackOdds();
        }
    }

    /**
     * Search for teams
     */
    async searchTeams(query: string): Promise<any[]> {
        try {
            // SportRadar doesn't have direct search, use competitions endpoint
            const response = await this.soccerClient.get('/competitions.json');
            // Filter teams from competitions
            return response.data?.competitions || [];
        } catch (error) {
            console.error('SportRadar searchTeams error:', error);
            return [];
        }
    }

    // ============ TRANSFORM METHODS ============

    private transformMatches(events: any[]): Match[] {
        return events.map(event => ({
            id: event.id,
            homeTeam: event.competitors?.find((c: any) => c.qualifier === 'home')?.name || 'Home',
            awayTeam: event.competitors?.find((c: any) => c.qualifier === 'away')?.name || 'Away',
            homeScore: event.sport_event_status?.home_score || 0,
            awayScore: event.sport_event_status?.away_score || 0,
            status: this.mapStatus(event.sport_event_status?.status),
            minute: event.sport_event_status?.clock?.played || undefined,
            league: event.sport_event_context?.competition?.name || 'Unknown League',
            leagueId: event.sport_event_context?.competition?.id || '',
            sport: 'Football',
            kickoff: new Date(event.scheduled),
            venue: event.venue?.name,
        }));
    }

    private transformMatchDetails(data: any): Match {
        const event = data.sport_event || {};
        const status = data.sport_event_status || {};
        
        return {
            id: event.id,
            homeTeam: event.competitors?.find((c: any) => c.qualifier === 'home')?.name || 'Home',
            awayTeam: event.competitors?.find((c: any) => c.qualifier === 'away')?.name || 'Away',
            homeScore: status.home_score || 0,
            awayScore: status.away_score || 0,
            status: this.mapStatus(status.status),
            minute: status.clock?.played,
            league: event.sport_event_context?.competition?.name || '',
            leagueId: event.sport_event_context?.competition?.id || '',
            sport: 'Football',
            kickoff: new Date(event.scheduled),
            venue: event.venue?.name,
            events: this.transformTimeline(data.timeline || []),
        };
    }

    private transformTimeline(timeline: any[]): MatchEvent[] {
        return timeline
            .filter(e => ['goal', 'yellow_card', 'red_card', 'substitution'].includes(e.type))
            .map(e => ({
                type: e.type,
                team: e.competitor || '',
                player: e.players?.[0]?.name,
                minute: e.match_clock || '',
                description: e.commentary,
            }));
    }

    private transformH2H(data: any, team1Id: string, team2Id: string): HeadToHead {
        const summaries = data.summaries || [];
        let team1Wins = 0, team2Wins = 0, draws = 0;
        let team1Goals = 0, team2Goals = 0;
        
        const matches: H2HMatch[] = summaries.slice(0, 10).map((s: any) => {
            const home = s.sport_event?.competitors?.find((c: any) => c.qualifier === 'home');
            const away = s.sport_event?.competitors?.find((c: any) => c.qualifier === 'away');
            const homeScore = s.sport_event_status?.home_score || 0;
            const awayScore = s.sport_event_status?.away_score || 0;
            
            if (home?.id === team1Id) {
                team1Goals += homeScore;
                team2Goals += awayScore;
                if (homeScore > awayScore) team1Wins++;
                else if (awayScore > homeScore) team2Wins++;
                else draws++;
            } else {
                team1Goals += awayScore;
                team2Goals += homeScore;
                if (awayScore > homeScore) team1Wins++;
                else if (homeScore > awayScore) team2Wins++;
                else draws++;
            }
            
            return {
                date: new Date(s.sport_event?.scheduled),
                competition: s.sport_event?.sport_event_context?.competition?.name || '',
                team1Score: home?.id === team1Id ? homeScore : awayScore,
                team2Score: home?.id === team1Id ? awayScore : homeScore,
                venue: home?.id === team1Id ? 'Home' : 'Away',
            };
        });

        return {
            team1: team1Id,
            team2: team2Id,
            team1Wins,
            team2Wins,
            draws,
            team1Goals,
            team2Goals,
            matches,
        };
    }

    private transformTeamForm(data: any, limit: number): TeamStats {
        const summaries = data.summaries?.slice(0, limit) || [];
        const competitor = data.competitor || {};
        
        let wins = 0, draws = 0, losses = 0, goalsFor = 0, goalsAgainst = 0;
        const form: string[] = [];
        
        summaries.forEach((s: any) => {
            const isHome = s.sport_event?.competitors?.find(
                (c: any) => c.id === competitor.id
            )?.qualifier === 'home';
            const homeScore = s.sport_event_status?.home_score || 0;
            const awayScore = s.sport_event_status?.away_score || 0;
            
            const teamScore = isHome ? homeScore : awayScore;
            const oppScore = isHome ? awayScore : homeScore;
            
            goalsFor += teamScore;
            goalsAgainst += oppScore;
            
            if (teamScore > oppScore) { wins++; form.push('W'); }
            else if (teamScore < oppScore) { losses++; form.push('L'); }
            else { draws++; form.push('D'); }
        });

        return {
            teamId: competitor.id,
            teamName: competitor.name,
            played: summaries.length,
            wins,
            draws,
            losses,
            goalsFor,
            goalsAgainst,
            points: wins * 3 + draws,
            position: 0,
            form,
        };
    }

    private transformStandings(data: any): TeamStats[] {
        const standings = data.standings?.[0]?.groups?.[0]?.standings || [];
        
        return standings.map((s: any, index: number) => ({
            teamId: s.competitor?.id,
            teamName: s.competitor?.name,
            played: s.played || 0,
            wins: s.win || 0,
            draws: s.draw || 0,
            losses: s.loss || 0,
            goalsFor: s.goals_for || 0,
            goalsAgainst: s.goals_against || 0,
            points: s.points || 0,
            position: index + 1,
            form: s.current_outcome?.split('') || [],
        }));
    }

    private transformInjuries(data: any): PlayerInjury[] {
        const players = data.competitor?.players || [];
        
        return players
            .filter((p: any) => p.injury)
            .map((p: any) => ({
                playerName: p.name,
                position: p.type || 'Unknown',
                injuryType: p.injury?.type || 'Unknown',
                status: p.injury?.status || 'doubtful',
                expectedReturn: p.injury?.expected_return,
            }));
    }

    private transformOdds(data: any): MatchOdds {
        const markets = data.markets || [];
        const threeWay = markets.find((m: any) => m.name === '3way');
        const overUnder = markets.find((m: any) => m.name === 'total' && m.specifier === '2.5');
        const btts = markets.find((m: any) => m.name === 'both_teams_to_score');
        
        return {
            homeWin: threeWay?.outcomes?.find((o: any) => o.name === '1')?.odds || 2.0,
            draw: threeWay?.outcomes?.find((o: any) => o.name === 'X')?.odds || 3.5,
            awayWin: threeWay?.outcomes?.find((o: any) => o.name === '2')?.odds || 3.0,
            over25: overUnder?.outcomes?.find((o: any) => o.name === 'over')?.odds || 1.9,
            under25: overUnder?.outcomes?.find((o: any) => o.name === 'under')?.odds || 1.9,
            btts: btts?.outcomes?.find((o: any) => o.name === 'yes')?.odds || 1.8,
        };
    }

    private mapStatus(status: string): Match['status'] {
        const statusMap: Record<string, Match['status']> = {
            'not_started': 'scheduled',
            'live': 'live',
            '1st_half': 'live',
            '2nd_half': 'live',
            'halftime': 'live',
            'ended': 'finished',
            'closed': 'finished',
            'postponed': 'postponed',
            'cancelled': 'cancelled',
        };
        return statusMap[status?.toLowerCase()] || 'scheduled';
    }

    // ============ FALLBACK DATA ============

    private getFallbackLiveMatches(): Match[] {
        const now = new Date();
        return [
            {
                id: 'live_1',
                homeTeam: 'Manchester United',
                awayTeam: 'Liverpool',
                homeScore: 2,
                awayScore: 1,
                status: 'live',
                minute: '67\'',
                league: 'Premier League',
                leagueId: 'sr:competition:17',
                sport: 'Football',
                kickoff: new Date(now.getTime() - 67 * 60000),
                events: [
                    { type: 'goal', team: 'Manchester United', player: 'Rashford', minute: '23\'' },
                    { type: 'goal', team: 'Liverpool', player: 'Salah', minute: '45\'' },
                    { type: 'goal', team: 'Manchester United', player: 'Bruno', minute: '56\'' },
                ],
            },
            {
                id: 'live_2',
                homeTeam: 'Bayern Munich',
                awayTeam: 'Dortmund',
                homeScore: 1,
                awayScore: 1,
                status: 'live',
                minute: '34\'',
                league: 'Bundesliga',
                leagueId: 'sr:competition:35',
                sport: 'Football',
                kickoff: new Date(now.getTime() - 34 * 60000),
            },
        ];
    }

    private getFallbackFixtures(): Match[] {
        const now = new Date();
        return [
            {
                id: 'fix_1',
                homeTeam: 'Arsenal',
                awayTeam: 'Chelsea',
                homeScore: 0,
                awayScore: 0,
                status: 'scheduled',
                league: 'Premier League',
                leagueId: 'sr:competition:17',
                sport: 'Football',
                kickoff: new Date(now.getTime() + 2 * 3600000),
            },
            {
                id: 'fix_2',
                homeTeam: 'Real Madrid',
                awayTeam: 'Barcelona',
                homeScore: 0,
                awayScore: 0,
                status: 'scheduled',
                league: 'La Liga',
                leagueId: 'sr:competition:8',
                sport: 'Football',
                kickoff: new Date(now.getTime() + 5 * 3600000),
            },
        ];
    }

    private getFallbackH2H(team1: string, team2: string): HeadToHead {
        return {
            team1,
            team2,
            team1Wins: 5,
            team2Wins: 3,
            draws: 2,
            team1Goals: 15,
            team2Goals: 12,
            matches: [
                { date: new Date(Date.now() - 30 * 86400000), competition: 'League', team1Score: 2, team2Score: 1, venue: 'Home' },
                { date: new Date(Date.now() - 90 * 86400000), competition: 'Cup', team1Score: 0, team2Score: 0, venue: 'Away' },
                { date: new Date(Date.now() - 180 * 86400000), competition: 'League', team1Score: 3, team2Score: 2, venue: 'Home' },
            ],
        };
    }

    private getFallbackInjuries(): PlayerInjury[] {
        return [
            { playerName: 'Player A', position: 'Midfielder', injuryType: 'Hamstring', status: 'out', expectedReturn: '2 weeks' },
            { playerName: 'Player B', position: 'Defender', injuryType: 'Knee', status: 'doubtful', expectedReturn: 'Game-time decision' },
        ];
    }

    private getFallbackOdds(): MatchOdds {
        return {
            homeWin: 2.10,
            draw: 3.40,
            awayWin: 3.20,
            over25: 1.90,
            under25: 1.90,
            btts: 1.75,
        };
    }
}

// Export singleton instance
const sportradarService = new SportRadarService();
export default sportradarService;
export { SportRadarService, Match, MatchOdds, TeamStats, HeadToHead, PlayerInjury };
