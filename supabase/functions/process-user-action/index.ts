import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.0.0"

serve(async (req) => {
  try {
    const { actionType, payload } = await req.json()

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: req.headers.get("Authorization")! } } }
    )

    switch (actionType) {
      case "ADD_FAVORITE": {
        const { error } = await supabase.from("user_favorites").upsert(payload)
        if (error) throw error
        break
      }
      case "REMOVE_FAVORITE": {
        const { error } = await supabase.from("user_favorites")
          .delete()
          .eq("user_id", payload.user_id)
          .eq("movie_id", payload.movie_id)
        if (error) throw error
        break
      }
      case "ADD_TO_WATCHLIST": {
        const { error } = await supabase.from("user_watchlist").upsert(payload)
        if (error) throw error
        break
      }
      case "REMOVE_FROM_WATCHLIST": {
        const { error } = await supabase.from("user_watchlist")
          .delete()
          .eq("user_id", payload.user_id)
          .eq("movie_id", payload.movie_id)
        if (error) throw error
        break
      }
      case "ADD_WATCHED": {
        const { error } = await supabase.from("user_watched_movies").upsert(payload)
        if (error) throw error
        break
      }
      case "REMOVE_WATCHED": {
        const { error } = await supabase.from("user_watched_movies")
          .delete()
          .eq("user_id", payload.user_id)
          .eq("movie_id", payload.movie_id)
        if (error) throw error
        break
      }
      case "RATE_MOVIE": {
        const { error } = await supabase.from("user_movie_ratings").upsert(payload)
        if (error) throw error
        break
      }
      case "REMOVE_RATING": {
        const { error } = await supabase.from("user_movie_ratings")
          .delete()
          .eq("user_id", payload.user_id)
          .eq("movie_id", payload.movie_id)
        if (error) throw error
        break
      }
      case "CREATE_CUSTOM_LIST": {
        const { error } = await supabase.from("user_custom_lists").upsert(payload)
        if (error) throw error
        break
      }
      case "UPDATE_CUSTOM_LIST": {
        const { error } = await supabase.from("user_custom_lists")
          .update(payload)
          .eq("id", payload.id)
          .eq("user_id", payload.user_id)
        if (error) throw error
        break
      }
      case "DELETE_CUSTOM_LIST": {
        const { error } = await supabase.from("user_custom_lists")
          .delete()
          .eq("id", payload.id)
          .eq("user_id", payload.user_id)
        if (error) throw error
        break
      }
      case "ADD_TO_CUSTOM_LIST": {
        const { error } = await supabase.from("user_custom_list_items").upsert(payload)
        if (error) throw error
        break
      }
      case "REMOVE_FROM_CUSTOM_LIST": {
        const { error } = await supabase.from("user_custom_list_items")
          .delete()
          .eq("list_id", payload.list_id)
          .eq("movie_id", payload.movie_id)
        if (error) throw error
        break
      }
      default:
        throw new Error(`Invalid action type: ${actionType}`)
    }

    return new Response(
      JSON.stringify({ success: true }),
      { headers: { "Content-Type": "application/json" } },
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    )
  }
})
