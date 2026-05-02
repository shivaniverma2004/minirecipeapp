# miniRecipe

A SwiftUI iOS recipe app backed by [Supabase](https://supabase.com) with native-feeling social flows (likes, follows, activity, and profile navigation).

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

3. **Database:** run `supabase/schema.sql` for a clean project. If you already have tables from an older version, run `supabase/migration_v2.sql` as well. The schema adds **follows**, **notifications**, **`recipe_likes`**, **`set_recipe_likes` RPC**, **avatars** storage, and tighter recipe RLS.

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

5. **Row Level Security:** Defined in `schema.sql` / `migration_v2.sql` (recipe read for all; insert only with `author_id = auth.uid()`; update/delete only for author; `recipe_likes` is user-owned).

6. **`profiles`:** Included in `schema.sql`; trigger creates a row on signup.

7. **Storage:** Buckets **`recipe-images`** and **`avatars`** (public read) with policies in the SQL files.

## App flow

- **Session:** Loading state → auth or **tab bar** (Recipes · Activity · Profile).
- **Recipes:** List, search, create; detail shows hero image, author, like/unlike, likes list (who liked), share; owners get **Edit / Delete**.
- **Activity:** Like/follow notifications deep-link to recipe/profile. Tapping your own user id routes to your **Profile tab**.
- **Profile:** Followers/following lists, follow actions, and self-routing behavior similar to Instagram-like apps.
- **Account settings:** Display name + avatar updates, password updates, and sign out.
- **Sign-up:** Email confirmation is handled with an on-screen message when no session is returned.
- **Offline list:** Stale data + banner when refresh fails (see `RecipeFeedViewModel`).

## Project layout (Swift)

| Path | Role |
| ---- | ---- |
| `miniRecipe/miniRecipeApp.swift` | Auth phase gate, session restore |
| `miniRecipe/ContentView.swift` | List, search, banner, sheets, sign-out confirm |
| `miniRecipe/RecipeFeedViewModel.swift` | Fetch, cache last success, filter |
| `miniRecipe/SupabaseManager.swift` | Auth, recipes, follows, likes, notifications, storage, profiles |
| `miniRecipe/AuthView.swift` | Custom sign in/up UI with password visibility toggle |
| `miniRecipe/RecipeDetailView.swift` | Recipe detail, likes list, author/profile routing |
| `miniRecipe/ProfileView.swift` | Profile card, follow lists, account entry |
| `miniRecipe/AccountSettingsView.swift` | Profile + security settings |
| `miniRecipe/APIError+UserMessage.swift` | Friendlier errors (RLS, network) |
| `miniRecipe/Config.swift` | Reads `SUPABASE_*` from Info; DEBUG fallbacks |
| `Secrets.example.xcconfig` | Template for local secrets |

## Security

- Use the **anon** key only; protect data with **RLS**. Never ship a **service role** key in the app.
- **Release** builds **fatalError** if `SUPABASE_URL` / `SUPABASE_ANON_KEY` are missing from the merged Info plist—configure `Secrets.xcconfig` for distribution.

