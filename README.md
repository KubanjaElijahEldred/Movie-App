# Movies App made in Flutter with.  api data from TMDB
# Movies App made in Flutter with.  api data from TMDB,

This is an app that, displays you details of movies that you can search for or browse.<br>

## Feature
<ul>
<li>Fetch api data from TMDB asynchronously.</li>
<li>Dynamic Theming using Provider</li>
<li>Search Functionality</li>

</ul>
Video Demo: https://youtu.be/5_bDIUYLWzg <br><br>
<a href ="https://play.google.com/store/apps/details?id=com.bimsina.movies"><img src ="https://play.google.com/intl/en/badges/images/generic/en_badge_web_generic.png"></a>
Screenshots:<br>
<table style={border:"none"}><tr>
<td><img src="https://user-images.githubusercontent.com/29589003/58170605-93aba280-7cb3-11e9-8733-dff46d1e86c7.png" alt="Screenshot 2"/></td>
<td><img src="https://user-images.githubusercontent.com/29589003/58170608-93aba280-7cb3-11e9-933f-395501d7a5a0.png" alt="Screenshot 1"/></td>
<td><img src="https://user-images.githubusercontent.com/29589003/58170610-94443900-7cb3-11e9-946f-79587eaa1043.png" alt="Screenshot 3"/></td>

</tr>
<tr>
<td><img src="https://user-images.githubusercontent.com/29589003/58170611-94443900-7cb3-11e9-8f01-ce5fe83bb93e.png" alt="Screenshot 1"/></td>

<td><img src="https://user-images.githubusercontent.com/29589003/58170612-94dccf80-7cb3-11e9-8955-ce6bba8b36dd.png" alt="Screenshot 2"/></td>
<td><img src="https://user-images.githubusercontent.com/29589003/58170613-94dccf80-7cb3-11e9-9182-a08922ae7139.png" alt="Screenshot 3"/></td>

</tr>

</table>

## To run this app


<ol>
<li>Obtain api key from <a href ="https://www.themoviedb.org/">TMDB</a>.</li>
<li>Replace YOUR_API_KEY in api_constants.dart with your api key.</li>
<li>Run the app with <b>flutter run --release</b></li>

</ol>

## Deploying to Vercel

Vercel has no Flutter runtime, so the app is compiled by the Flutter SDK in CI
and the finished static bundle is uploaded to Vercel.

Every push to `main` runs `.github/workflows/deploy.yml`, which builds the web
app and deploys it to https://play-it-movies.vercel.app.

To deploy from your machine instead, run:

```bash
./scripts/deploy_vercel.sh
```

It performs the identical build and deploy steps. The host/routing rules live in
`vercel.json`, which CI copies into the static bundle before upload.

### Required repository secrets

| Secret | Value |
| --- | --- |
| `VERCEL_TOKEN` | Vercel access token |
| `VERCEL_ORG_ID` | Vercel team id (`team_fZRLHANF66J2q79gKeisPDlt`) |
| `VERCEL_PROJECT_ID` | Vercel project id (`prj_4TFGQN3cz9AJQyybov9yns4MIYbk`) |

### Why the Vercel Git integration is set to skip builds

The project is connected to this GitHub repository, so Vercel's Git
integration would normally also try to build every push. It cannot: there is no
Flutter runtime on Vercel, so that build produces an empty deployment and
overwrites the good one, taking the site down to a 404.

To prevent that, the project's **Ignored Build Step** is set to `exit 0`. A zero
exit code tells Vercel to skip the build, so pushes produce no Vercel-side
deployment and CI stays the only thing that publishes to production. Verified
behaviour on a push: the Git-triggered deployment ends up `CANCELED` while the
Actions deployment is `READY` and serves production.

If you ever remove that setting, re-add it with:

```bash
curl -X PATCH "https://api.vercel.com/v9/projects/prj_4TFGQN3cz9AJQyybov9yns4MIYbk?teamId=team_fZRLHANF66J2q79gKeisPDlt" \
  -H "Authorization: Bearer $VERCEL_TOKEN" -H "Content-Type: application/json" \
  -d '{"commandForIgnoringBuildStep":"exit 0"}'
```

### Web-specific note on remote images

Flutter web loads `NetworkImage` through `XMLHttpRequest`, so every remote image
host must return `Access-Control-Allow-Origin`. TMDB's `image.tmdb.org` does,
which is why posters load on the web. A plain `<img>` would tolerate a missing
CORS header, so an image that works on Android or iOS can still fail on web.
Keep new remote images on a CORS-enabled host.
