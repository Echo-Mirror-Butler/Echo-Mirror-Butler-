import { useEffect, useState } from 'react';
import { supabase } from '../../lib/supabase';
import { useAuth } from '../../lib/auth-context';

interface LeaderboardEntry {
  id: string;
  display_name: string | null;
  avatar_url: string | null;
  leaderboard_anonymous: boolean;
  echo_earned_this_week: number;
  rank: number;
}

export function LeaderboardPage() {
  const { user } = useAuth();
  const [entries, setEntries] = useState<LeaderboardEntry[]>([]);
  const [userRank, setUserRank] = useState<number | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchLeaderboard = async () => {
    try {
      setLoading(true);
      const { data, error } = await supabase
        .from('leaderboard_weekly')
        .select('*')
        .order('rank', { ascending: true })
        .limit(20);

      if (error) throw error;

      const processed = (data || []).map((entry: LeaderboardEntry) => ({
        ...entry,
        display_name: entry.leaderboard_anonymous ? 'Anonymous' : entry.display_name || 'User',
      }));

      setEntries(processed);

      if (user?.id) {
        const { data: userData } = await supabase
          .from('leaderboard_weekly')
          .select('rank')
          .eq('id', user.id)
          .maybeSingle();

        if (userData) setUserRank(userData.rank);
      }
    } catch (err) {
      setError('Failed to load leaderboard');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchLeaderboard();
    const interval = setInterval(fetchLeaderboard, 5 * 60 * 1000);
    return () => clearInterval(interval);
  }, [user]);

  if (loading) return <div className="flex justify-center items-center h-64"><div className="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600"></div></div>;
  if (error) return <div className="text-center py-12"><p className="text-red-500">{error}</p><button onClick={fetchLeaderboard} className="mt-4 px-4 py-2 bg-indigo-600 text-white rounded">Retry</button></div>;

  return (
    <div className="max-w-4xl mx-auto px-4 py-8">
      <h1 className="text-3xl font-bold text-gray-900 mb-6">🏆 Weekly Leaderboard</h1>
      <p className="text-gray-600 mb-8">Top ECHO earners this week. Consistency is key!</p>
      <div className="bg-white rounded-xl shadow-lg overflow-hidden">
        <div className="divide-y divide-gray-200">
          {entries.length === 0 ? (
            <div className="text-center py-12"><p className="text-gray-500">No one has earned ECHO this week yet.</p></div>
          ) : (
            entries.map((entry) => {
              const isCurrentUser = user?.id === entry.id;
              return (
                <div key={entry.id} className={`flex items-center px-6 py-4 ${isCurrentUser ? 'bg-indigo-50 border-l-4 border-indigo-600' : ''}`}>
                  <div className="flex-shrink-0 w-12 text-center">
                    <span className={`text-lg font-bold ${entry.rank <= 3 ? 'text-yellow-500' : 'text-gray-400'}`}>#{entry.rank}</span>
                  </div>
                  <div className="flex-shrink-0 mr-4">
                    {entry.avatar_url ? (
                      <img src={entry.avatar_url} alt={entry.display_name || 'User'} className="w-10 h-10 rounded-full object-cover" />
                    ) : (
                      <div className="w-10 h-10 rounded-full bg-gray-200 flex items-center justify-center">
                        <span className="text-gray-500 text-lg">{entry.display_name?.charAt(0) || '?'}</span>
                      </div>
                    )}
                  </div>
                  <div className="flex-1">
                    <p className={`font-medium ${isCurrentUser ? 'text-indigo-700' : 'text-gray-900'}`}>
                      {entry.display_name || 'User'}
                      {isCurrentUser && <span className="ml-2 text-xs bg-indigo-100 text-indigo-700 px-2 py-0.5 rounded-full">You</span>}
                    </p>
                  </div>
                  <div className="flex-shrink-0 text-right">
                    <p className="text-lg font-bold text-indigo-600">{entry.echo_earned_this_week} ECHO</p>
                    <p className="text-xs text-gray-500">earned this week</p>
                  </div>
                </div>
              );
            })
          )}
        </div>
      </div>
      {userRank !== null && userRank > 20 && (
        <div className="mt-6 p-4 bg-gray-50 rounded-lg border border-gray-200 text-center">
          <p className="text-gray-600">Your rank: <span className="font-bold text-indigo-600">#{userRank}</span></p>
          <p className="text-sm text-gray-500 mt-1">Keep logging daily to climb the leaderboard!</p>
        </div>
      )}
    </div>
  );
}