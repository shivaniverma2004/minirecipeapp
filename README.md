# miniRecipe

A small **SwiftUI** iOS app for browsing and creating recipes, backed by [Supabase](https://supabase.com) (Postgres + Auth + optional Storage).

## Requirements

- Xcode 16+ (project targets recent iOS SDKs)
- A Supabase project with `recipes` (and optionally `profiles`) tables

## Setup

1. **Secrets (required for Release; recommended for Debug)**  
   - Copy the example config and edit your values:
     ```bash
     cp Secrets.example.xcconfig Secrets.xcconfig
     ```
   - In `Secrets.xcconfig`, set `SUPABASE_URL` (via `SUPABASE_URL_PART1` + `SUPABASE_URL_PART2`) and `SUPABASE_ANON_KEY` as in `Secrets.example.xcconfig`.  
     **Important:** In `.xcconfig`, `//` starts a comment, so never put `https://…` on one line—it gets cut off. Split into `https:/` and `/your-project.supabase.co` and combine with `$(…)`.
   - `Secrets.xcconfig` is listed in `.gitignore` so keys are not committed.
   - The **miniRecipe** target already uses this file as its **Based on Configuration File**. If you open the project on a new machine, create `Secrets.xcconfig` as above before building.

2. Open `miniRecipe.xcodeproj` and build. Swift Package Manager will fetch **supabase-swift**.

3. **Database:** run `supabase/schema.sql` for a clean project. If you already have tables from an older version, run `supabase/migration_v2.sql` as well. The schema adds **follows**, **notifications**, **`set_recipe_likes` RPC**, **avatars** storage, and tighter recipe RLS (only the author can edit/delete; anyone signed in can like via RPC).

4. **Database (columns):** ensure a `recipes` table compatible with the `Recipe` model:

   | Column        | Notes                          |
   | ------------- | ------------------------------ |
   | `id`          | text/uuid                      |
   | `title`       | text                           |
   | `description` | text, nullable                 |
   | `image_url`   | text, nullable                 |
   | `author_id`   | text (UUID string, matches `auth.users`) |
   | `likes`       | integer, nullable              |
   | `created_at`  | timestamptz or ISO text        |

5. **Row Level Security:** Defined in `schema.sql` / `migration_v2.sql` (recipe read for all; insert only with `author_id = auth.uid()`; update/delete only for author; likes via **`set_recipe_likes`** RPC).

6. **`profiles`:** Included in `schema.sql`; trigger creates a row on signup.

7. **Storage:** Buckets **`recipe-images`** and **`avatars`** (public read) with policies in the SQL files.

## App flow

- **Session:** Loading state → auth or **tab bar** (Recipes · Activity · Profile).
- **Recipes:** List, search, create; detail shows hero image, author (links to profile), like (creates an in-app **notification** for the author), share; owners get **Edit / Delete**.
- **Activity:** In-app notifications (likes, follows)—not push/APNs. **Sign in** required.
- **Profile:** Your recipes, followers/following counts, **follow** other cooks; **Account** settings for display name, **profile photo**, **password**, sign out.
- **Sign-up:** Email confirmation is handled with an on-screen message when no session is returned.
- **Offline list:** Stale data + banner when refresh fails (see `RecipeFeedViewModel`).

## Project layout (Swift)

| Path | Role |
| ---- | ---- |
| `miniRecipe/miniRecipeApp.swift` | Auth phase gate, session restore |
| `miniRecipe/ContentView.swift` | List, search, banner, sheets, sign-out confirm |
| `miniRecipe/RecipeFeedViewModel.swift` | Fetch, cache last success, filter |
| `miniRecipe/SupabaseManager.swift` | Auth, recipes, likes patch, storage, profiles |
| `miniRecipe/AuthView.swift` | Sign in/up + email confirmation messaging |
| `miniRecipe/RecipeDetailView.swift` | Profile, persisted likes |
| `miniRecipe/APIError+UserMessage.swift` | Friendlier errors (RLS, network) |
| `miniRecipe/Config.swift` | Reads `SUPABASE_*` from Info; DEBUG fallbacks |
| `Secrets.example.xcconfig` | Template for local secrets |

## Security

- Use the **anon** key only; protect data with **RLS**. Never ship a **service role** key in the app.
- **Release** builds **fatalError** if `SUPABASE_URL` / `SUPABASE_ANON_KEY` are missing from the merged Info plist—configure `Secrets.xcconfig` for distribution.

## License

Add your license here if you distribute the project.
