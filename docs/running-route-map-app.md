# RunRoute Japan Web App

## Overview

RunRoute Japan is a browser-based running route map application deployed as the
Tomcat `ROOT.war` static front end. It creates a runnable course from a start
point to a destination, shows the route elevation profile, and checks whether
the user's current location is near the generated course.

The current implementation is designed as a learning/prototype application. It
does not store user location data on the server.

## Main Features

- Japan map display using Leaflet and GSI map tiles.
- Destination selection by clicking the map.
- Start point selection from browser geolocation or the current map center.
- Walking/running route generation using OSRM's `foot` profile.
- Elevation profile using GSI DEM tiles first, with Open-Meteo elevation API as
  a fallback.
- Route metrics:
  - distance
  - elevation gain
  - elevation loss
  - elevation range
- Real-time on-route check using browser geolocation `watchPosition`.

## Files

| File | Role |
| --- | --- |
| `app/tomcat-app/src/main/webapp/run-route/index.html` | Main UI and app layout |
| `app/tomcat-app/src/main/webapp/run-route/styles.css` | Map-focused responsive design |
| `app/tomcat-app/src/main/webapp/run-route/app.js` | Map, route, elevation, and tracking logic |
| `app/tomcat-app/src/main/java/com/example/learning/HomeServlet.java` | Existing API remains available, but is not required by this app |

## Runtime Flow

1. The browser loads `index.html`, `styles.css`, `app.js`, and Leaflet.
2. Leaflet displays GSI standard map tiles.
3. The user sets the start point:
   - click the location button to use browser geolocation, or
   - click `地図中心をスタートにする`.
4. The user clicks the map to set the goal.
5. `app.js` calls OSRM:
   - `https://router.project-osrm.org/route/v1/foot/{lng,lat};{lng,lat}`
   - `overview=full`
   - `geometries=geojson`
6. The returned route geometry is drawn as a line on the map.
7. The route is sampled to at most 90 points.
8. Elevation is calculated:
   - first by reading GSI `dem_png` tiles in the browser,
   - then by falling back to Open-Meteo `/v1/elevation` if needed.
9. The app calculates distance, ascent, descent, and elevation range.
10. If real-time tracking is started, the app watches browser geolocation and
    calculates the nearest route segment.

## HTTPS Requirement

Browser geolocation requires a secure context in modern browsers. For this
project, that means:

- local development can use `http://localhost` or `http://127.0.0.1`;
- the deployed ALB/domain should use HTTPS for real current-location tracking.

If the app is deployed only on HTTP, route creation still works with the manual
start point button, but current-location retrieval and real-time tracking will
not work reliably.

## Route Judgment

The app treats the user as being on the course when the nearest route segment is
within `40m`.

This value is defined in `app.js`:

```js
const ROUTE_THRESHOLD_METERS = 40;
```

For dense city areas, a smaller threshold may be useful. For GPS noise, tall
buildings, parks, and riverside paths, a larger threshold may be less noisy.

## Prototype Limitations

- OSRM public endpoints are suitable for learning and prototypes, not guaranteed
  production service.
- The `foot` route follows the available OpenStreetMap routing graph; it does
  not know all local running preferences.
- Elevation is terrain elevation, not bridge, overpass, building, or tunnel
  elevation.
- The app does not yet support named place search, GPX export, saved routes, or
  multi-waypoint course planning.

## Production Improvement Ideas

- Use a contracted routing provider or self-host OSRM/Valhalla/GraphHopper.
- Add place search for Japanese addresses and landmarks.
- Add waypoint editing for round-trip running routes.
- Add GPX export/import.
- Add route safety hints such as major-road avoidance and park/path preference.
- Add HTTPS with ACM so geolocation works on the deployed domain.
- Add monitoring for external API failures.

## Deployment

The app is included in the existing Maven WAR build.

Normal deployment flow:

```bash
git add app/tomcat-app/src/main/webapp/run-route docs/running-route-map-app.md
git commit -m "Add running route map application"
git push origin main
```

After GitHub push, CodePipeline builds the WAR and CodeDeploy replaces the
application files on the EC2/Tomcat environment.

## Post-Deploy Checks

```bash
curl -I http://app.filanza-aws.com/
curl -I http://app.filanza-aws.com/styles.css
curl -I http://app.filanza-aws.com/app.js
```

Expected content types:

- `/` returns `text/html`
- `/styles.css` returns `text/css`
- `/app.js` returns JavaScript content

Open the site in a browser, click `皇居周辺サンプル`, then click
`コースを作成`.

For real-time tracking, complete HTTPS setup first.
