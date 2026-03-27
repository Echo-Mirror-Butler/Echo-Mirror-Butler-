import { createClient, SupabaseClient } from '@supabase/supabase-js';

class SupabaseService {
  private client: SupabaseClient;

  constructor() {
    if (!process.env.SUPABASE_URL || !process.env.SUPABASE_SERVICE_ROLE_KEY) {
      throw new Error('Missing Supabase environment variables');
    }

    this.client = createClient(
      process.env.SUPABASE_URL,
      process.env.SUPABASE_SERVICE_ROLE_KEY,
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      }
    );
  }

  // Get the Supabase client instance
  getClient(): SupabaseClient {
    return this.client;
  }

  // User profile operations
  async getUserProfile(userId: string) {
    const { data, error } = await this.client
      .from('profiles')
      .select('*')
      .eq('id', userId)
      .single();

    if (error) {throw error;}
    return data;
  }

  async updateUserProfile(userId: string, updates: any) {
    const { data, error } = await this.client
      .from('profiles')
      .update(updates)
      .eq('id', userId)
      .select()
      .single();

    if (error) {throw error;}
    return data;
  }

  // Stellar transaction operations
  async createStellarTransaction(transaction: any) {
    const { data, error } = await this.client
      .from('stellar_transactions')
      .insert(transaction)
      .select()
      .single();

    if (error) {throw error;}
    return data;
  }

  async getStellarTransactions(userId: string, limit = 50) {
    const { data, error } = await this.client
      .from('stellar_transactions')
      .select('*')
      .eq('user_id', userId)
      .order('created_at', { ascending: false })
      .limit(limit);

    if (error) {throw error;}
    return data;
  }

  // Webhook logging
  async logWebhook(webhookData: any) {
    const { data, error } = await this.client
      .from('webhook_logs')
      .insert(webhookData)
      .select()
      .single();

    if (error) {throw error;}
    return data;
  }

  // Health check
  async healthCheck() {
    try {
      const { error } = await this.client
        .from('profiles')
        .select('count')
        .limit(1);

      return {
        status: error ? 'error' : 'healthy',
        error: error?.message,
        timestamp: new Date().toISOString()
      };
    } catch (err) {
      return {
        status: 'error',
        error: err instanceof Error ? err.message : 'Unknown error',
        timestamp: new Date().toISOString()
      };
    }
  }
}

// Singleton instance
export const supabaseService = new SupabaseService();
export default supabaseService;
