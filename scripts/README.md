# Scripts

| Script | When to run |
|--------|------------|
| `deploy_supabase.sh` | After local migration changes / Edge Function changes — pushes to your linked production Supabase project. |
| `build_android_release.sh` | Build a signed `.aab` for Google Play upload. Requires `android/key.properties` and `SUPABASE_URL`/`SUPABASE_ANON_KEY` env vars. |

## First-time Supabase production setup

1. Create a project at https://supabase.com/dashboard
   - Region: **Northeast Asia (Seoul)** — lowest latency for Korean users
   - Save the DB password securely
2. From the project root:
   ```bash
   supabase link --project-ref <your-project-ref>
   ```
3. Set the Anthropic key:
   ```bash
   supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
   ```
4. Run the deploy script:
   ```bash
   ./scripts/deploy_supabase.sh
   ```
5. (Recommended) In the Supabase dashboard:
   - Auth → Providers → Email → enable "Confirm email"
   - Auth → Email Templates → translate to Korean
   - Database → Backups → set up daily backups (default for Pro plan)

## First-time Android signing setup

1. Generate the upload keystore (one-time, **never** regenerate):
   ```bash
   keytool -genkey -v \
     -keystore ~/onyu-upload-keystore.jks \
     -keyalg RSA -keysize 2048 -validity 10000 \
     -alias onyu-upload
   ```
   You'll be prompted for a password — store it in a password manager.
2. Copy the keystore to a backup location (cloud password manager attachment, encrypted USB, etc.)
3. From the project root:
   ```bash
   cp app/android/key.properties.example app/android/key.properties
   ```
4. Edit `app/android/key.properties` with your password and the keystore path.
5. Verify:
   ```bash
   export SUPABASE_URL=https://<ref>.supabase.co
   export SUPABASE_ANON_KEY=<sb_publishable_...>
   ./scripts/build_android_release.sh
   ```
   Output bundle: `app/build/app/outputs/bundle/release/app-release.aab`
