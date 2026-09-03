(() => {
  "use strict";

  const app = {
    map: null,
    start: null,
    goal: null,
    route: [],
    routeDistances: [],
    elevations: [],
    watchId: null,
    lastTrackAt: 0,
    lastTrackPoint: null,
    markers: {},
    routeLayer: null,
    tileLayer: null
  };

  const NISHIARAI_CENTER = { lat: 35.77705, lng: 139.79067 };
  const TONERI_PARK = { lat: 35.79655, lng: 139.77066 };
  const SERVICE_AREA_RADIUS_METERS = 20000;
  const MAX_ROUTE_DISTANCE_METERS = 25000;
  const MAX_ELEVATION_SAMPLES = 40;
  const ROUTE_THRESHOLD_METERS = 50;
  const TRACK_MIN_INTERVAL_MS = 3000;
  const TRACK_MIN_MOVE_METERS = 10;
  const ROUTING_API_BASE = "https://routing.openstreetmap.de/routed-foot/route/v1/driving";

  const elements = {
    locate: document.getElementById("locate-button"),
    useCenter: document.getElementById("use-center-button"),
    sample: document.getElementById("sample-button"),
    build: document.getElementById("build-route-button"),
    track: document.getElementById("track-button"),
    status: document.getElementById("status-message"),
    start: document.getElementById("start-label"),
    goal: document.getElementById("goal-label"),
    distance: document.getElementById("distance-value"),
    gain: document.getElementById("gain-value"),
    loss: document.getElementById("loss-value"),
    range: document.getElementById("range-value"),
    elevationSource: document.getElementById("elevation-source"),
    minElevation: document.getElementById("min-elevation"),
    maxElevation: document.getElementById("max-elevation"),
    canvas: document.getElementById("elevation-chart"),
    mapLoading: document.getElementById("map-loading"),
    trackState: document.getElementById("track-state"),
    trackingCard: document.getElementById("tracking-card"),
    onRoute: document.getElementById("on-route-label"),
    nearestDistance: document.getElementById("nearest-distance"),
    progressBar: document.getElementById("progress-bar"),
    progressLabel: document.getElementById("progress-label")
  };

  function setStatus(message) {
    elements.status.textContent = message;
  }

  function isInServiceArea(point) {
    return haversine(NISHIARAI_CENTER, point) <= SERVICE_AREA_RADIUS_METERS;
  }

  function validatePoint(point, label) {
    if (isInServiceArea(point)) return true;
    setStatus(`${label}は対象エリア外です。西新井駅から半径20km以内を指定してください。`);
    return false;
  }

  function formatCoordinate(point) {
    if (!point) return "未設定";
    return `${point.lat.toFixed(5)}, ${point.lng.toFixed(5)}`;
  }

  function syncControls() {
    elements.start.textContent = formatCoordinate(app.start);
    elements.goal.textContent = app.goal ? formatCoordinate(app.goal) : "地図クリックで指定";
    elements.build.disabled = !(app.start && app.goal);
    elements.track.disabled = app.route.length < 2;
  }

  function makeMarkerHtml(className, label) {
    return `<span class="${className}">${label}</span>`;
  }

  function setMarker(name, point, className, label) {
    if (app.markers[name]) app.markers[name].remove();
    const icon = L.divIcon({
      html: makeMarkerHtml(className, label),
      className: "",
      iconSize: [25, 25],
      iconAnchor: [12, 12]
    });
    app.markers[name] = L.marker(point, { icon }).addTo(app.map);
  }

  function setStart(point, moveMap = false) {
    if (!validatePoint(point, "スタート地点")) return false;
    app.start = point;
    setMarker("start", point, "start-marker", "S");
    if (moveMap) app.map.setView(point, 15);
    syncControls();
    return true;
  }

  function setGoal(point) {
    if (!validatePoint(point, "目的地")) return false;
    app.goal = point;
    setMarker("goal", point, "goal-marker", "G");
    syncControls();
    return true;
  }

  function haversine(a, b) {
    const radius = 6371000;
    const toRad = (deg) => deg * Math.PI / 180;
    const dLat = toRad(b.lat - a.lat);
    const dLng = toRad(b.lng - a.lng);
    const lat1 = toRad(a.lat);
    const lat2 = toRad(b.lat);
    const h = Math.sin(dLat / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2;
    return 2 * radius * Math.asin(Math.sqrt(h));
  }

  function buildCumulativeDistances(points) {
    const distances = [0];
    for (let i = 1; i < points.length; i += 1) {
      distances.push(distances[i - 1] + haversine(points[i - 1], points[i]));
    }
    return distances;
  }

  function sampleRoute(points, maxSamples = MAX_ELEVATION_SAMPLES) {
    if (points.length <= maxSamples) return points;
    const distances = buildCumulativeDistances(points);
    const total = distances.at(-1);
    const sampled = [];
    for (let i = 0; i < maxSamples; i += 1) {
      const target = total * (i / (maxSamples - 1));
      const index = distances.findIndex((distance) => distance >= target);
      sampled.push(points[Math.max(0, index)]);
    }
    return sampled;
  }

  function updateMetrics(points, elevations) {
    const totalDistance = app.routeDistances.at(-1) || 0;
    let gain = 0;
    let loss = 0;
    for (let i = 1; i < elevations.length; i += 1) {
      const diff = elevations[i] - elevations[i - 1];
      if (diff > 1) gain += diff;
      if (diff < -1) loss += Math.abs(diff);
    }
    const min = Math.min(...elevations);
    const max = Math.max(...elevations);
    elements.distance.textContent = `${(totalDistance / 1000).toFixed(2)} km`;
    elements.gain.textContent = `${Math.round(gain)} m`;
    elements.loss.textContent = `${Math.round(loss)} m`;
    elements.range.textContent = `${Math.round(max - min)} m`;
    elements.minElevation.textContent = `${Math.round(min)} m`;
    elements.maxElevation.textContent = `${Math.round(max)} m`;
    if (!points.length) drawEmptyChart("ルート作成後に高低差を表示します");
  }

  function drawEmptyChart(message) {
    const canvas = elements.canvas;
    const ctx = canvas.getContext("2d");
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    ctx.fillStyle = "#eef6ed";
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.fillStyle = "#66746e";
    ctx.font = "24px system-ui, sans-serif";
    ctx.textAlign = "center";
    ctx.fillText(message, canvas.width / 2, canvas.height / 2);
  }

  function drawElevationChart(elevations) {
    if (!elevations.length) {
      drawEmptyChart("標高を取得できませんでした");
      return;
    }
    const canvas = elements.canvas;
    const ctx = canvas.getContext("2d");
    const width = canvas.width;
    const height = canvas.height;
    const padding = { top: 22, right: 22, bottom: 34, left: 44 };
    const min = Math.min(...elevations);
    const max = Math.max(...elevations);
    const range = Math.max(1, max - min);

    ctx.clearRect(0, 0, width, height);
    ctx.fillStyle = "#f9fcf8";
    ctx.fillRect(0, 0, width, height);

    ctx.strokeStyle = "#dbe5df";
    ctx.lineWidth = 1;
    for (let i = 0; i < 4; i += 1) {
      const y = padding.top + ((height - padding.top - padding.bottom) * i / 3);
      ctx.beginPath();
      ctx.moveTo(padding.left, y);
      ctx.lineTo(width - padding.right, y);
      ctx.stroke();
    }

    const points = elevations.map((elevation, index) => {
      const x = padding.left + ((width - padding.left - padding.right) * index / (elevations.length - 1));
      const y = height - padding.bottom - ((elevation - min) / range) * (height - padding.top - padding.bottom);
      return { x, y };
    });

    ctx.beginPath();
    ctx.moveTo(points[0].x, height - padding.bottom);
    points.forEach((point) => ctx.lineTo(point.x, point.y));
    ctx.lineTo(points.at(-1).x, height - padding.bottom);
    ctx.closePath();
    const gradient = ctx.createLinearGradient(0, padding.top, 0, height - padding.bottom);
    gradient.addColorStop(0, "rgba(36, 122, 75, .34)");
    gradient.addColorStop(1, "rgba(36, 122, 75, .04)");
    ctx.fillStyle = gradient;
    ctx.fill();

    ctx.beginPath();
    points.forEach((point, index) => {
      if (index === 0) ctx.moveTo(point.x, point.y);
      else ctx.lineTo(point.x, point.y);
    });
    ctx.strokeStyle = "#247a4b";
    ctx.lineWidth = 4;
    ctx.lineJoin = "round";
    ctx.lineCap = "round";
    ctx.stroke();

    ctx.fillStyle = "#66746e";
    ctx.font = "18px system-ui, sans-serif";
    ctx.textAlign = "left";
    ctx.fillText(`${Math.round(max)}m`, 10, padding.top + 8);
    ctx.fillText(`${Math.round(min)}m`, 10, height - padding.bottom + 6);
  }

  function lonLatToTile(point, zoom) {
    const latRad = point.lat * Math.PI / 180;
    const scale = 2 ** zoom;
    const x = (point.lng + 180) / 360 * scale;
    const y = (1 - Math.log(Math.tan(latRad) + 1 / Math.cos(latRad)) / Math.PI) / 2 * scale;
    return {
      x: Math.floor(x),
      y: Math.floor(y),
      px: Math.floor((x - Math.floor(x)) * 256),
      py: Math.floor((y - Math.floor(y)) * 256)
    };
  }

  function decodeGsiElevation(red, green, blue) {
    const value = 65536 * red + 256 * green + blue;
    if (value === 8388608) return null;
    return value < 8388608 ? value * 0.01 : (value - 16777216) * 0.01;
  }

  const tileCache = new Map();
  function loadImage(url) {
    if (tileCache.has(url)) return tileCache.get(url);
    const promise = new Promise((resolve, reject) => {
      const image = new Image();
      const timeoutId = window.setTimeout(() => reject(new Error("標高タイルの取得がタイムアウトしました")), 8000);
      image.crossOrigin = "anonymous";
      image.onload = () => {
        window.clearTimeout(timeoutId);
        resolve(image);
      };
      image.onerror = () => {
        window.clearTimeout(timeoutId);
        reject(new Error("標高タイルを取得できませんでした"));
      };
      image.src = url;
    });
    tileCache.set(url, promise);
    return promise;
  }

  async function fetchJson(url, timeoutMs) {
    const controller = new AbortController();
    const timeoutId = window.setTimeout(() => controller.abort(), timeoutMs);
    try {
      const response = await fetch(url, { signal: controller.signal });
      if (!response.ok) throw new Error(`外部APIエラー (${response.status})`);
      return await response.json();
    } catch (error) {
      if (error.name === "AbortError") throw new Error("外部APIの応答がタイムアウトしました");
      throw error;
    } finally {
      window.clearTimeout(timeoutId);
    }
  }

  async function fetchGsiElevations(points) {
    const zoom = 14;
    const canvas = document.createElement("canvas");
    canvas.width = 256;
    canvas.height = 256;
    const ctx = canvas.getContext("2d", { willReadFrequently: true });
    const results = [];
    for (const point of points) {
      const tile = lonLatToTile(point, zoom);
      const url = `https://cyberjapandata.gsi.go.jp/xyz/dem_png/${zoom}/${tile.x}/${tile.y}.png`;
      const image = await loadImage(url);
      ctx.clearRect(0, 0, 256, 256);
      ctx.drawImage(image, 0, 0);
      const data = ctx.getImageData(tile.px, tile.py, 1, 1).data;
      const elevation = decodeGsiElevation(data[0], data[1], data[2]);
      results.push(elevation);
    }
    if (results.some((value) => value === null || Number.isNaN(value))) {
      throw new Error("Some GSI elevation values are unavailable");
    }
    return results;
  }

  async function fetchOpenMeteoElevations(points) {
    const elevations = [];
    const chunkSize = 80;
    for (let index = 0; index < points.length; index += chunkSize) {
      const chunk = points.slice(index, index + chunkSize);
      const latitudes = chunk.map((point) => point.lat.toFixed(6)).join(",");
      const longitudes = chunk.map((point) => point.lng.toFixed(6)).join(",");
      const data = await fetchJson(
        `https://api.open-meteo.com/v1/elevation?latitude=${latitudes}&longitude=${longitudes}`,
        15000
      );
      elevations.push(...data.elevation);
    }
    return elevations;
  }

  async function getElevations(points) {
    try {
      const values = await fetchGsiElevations(points);
      elements.elevationSource.textContent = "国土地理院 DEM";
      return values;
    } catch (error) {
      const values = await fetchOpenMeteoElevations(points);
      elements.elevationSource.textContent = "Open-Meteo DEM";
      return values;
    }
  }

  async function buildRoute() {
    if (!app.start || !app.goal) return;
    elements.build.disabled = true;
    setStatus("ルートを作成中です。道路ネットワークと標高を取得しています。");
    try {
      const coordinates = `${app.start.lng},${app.start.lat};${app.goal.lng},${app.goal.lat}`;
      const url = `${ROUTING_API_BASE}/${coordinates}?overview=full&geometries=geojson&steps=false`;
      const data = await fetchJson(url, 20000);
      const route = data.routes?.[0];
      if (!route) throw new Error("Route not found");

      const routePoints = route.geometry.coordinates.map(([lng, lat]) => ({ lat, lng }));
      const routeDistances = buildCumulativeDistances(routePoints);
      const totalDistance = routeDistances.at(-1) || 0;
      if (totalDistance > MAX_ROUTE_DISTANCE_METERS) {
        throw new Error(`コースが${(totalDistance / 1000).toFixed(1)}kmあります。25km以内になるよう目的地を近づけてください`);
      }
      if (routePoints.some((point) => !isInServiceArea(point))) {
        throw new Error("コースの一部が西新井駅から半径20kmの対象エリア外です");
      }
      app.route = routePoints;
      app.routeDistances = routeDistances;
      if (app.routeLayer) app.routeLayer.remove();
      app.routeLayer = L.polyline(app.route, {
        color: "#247a4b",
        weight: 7,
        opacity: .9,
        lineJoin: "round"
      }).addTo(app.map);
      app.map.fitBounds(app.routeLayer.getBounds(), { padding: [30, 30] });

      const sampled = sampleRoute(app.route);
      app.elevations = await getElevations(sampled);
      drawElevationChart(app.elevations);
      updateMetrics(sampled, app.elevations);
      setStatus("コースを作成しました。高低差と現在地判定を確認できます。");
    } catch (error) {
      setStatus(`ルート作成に失敗しました: ${error.message}`);
    } finally {
      syncControls();
    }
  }

  function projectPointToSegment(point, start, end) {
    const metersPerDegreeLat = 111320;
    const metersPerDegreeLng = 111320 * Math.cos(point.lat * Math.PI / 180);
    const px = (point.lng - start.lng) * metersPerDegreeLng;
    const py = (point.lat - start.lat) * metersPerDegreeLat;
    const vx = (end.lng - start.lng) * metersPerDegreeLng;
    const vy = (end.lat - start.lat) * metersPerDegreeLat;
    const lengthSquared = vx * vx + vy * vy;
    const t = lengthSquared === 0 ? 0 : Math.max(0, Math.min(1, (px * vx + py * vy) / lengthSquared));
    return {
      distance: Math.hypot(px - vx * t, py - vy * t),
      ratio: t
    };
  }

  function findNearestRoutePoint(point) {
    let best = { distance: Infinity, routeDistance: 0 };
    for (let i = 1; i < app.route.length; i += 1) {
      const projection = projectPointToSegment(point, app.route[i - 1], app.route[i]);
      if (projection.distance < best.distance) {
        const segmentDistance = app.routeDistances[i] - app.routeDistances[i - 1];
        best = {
          distance: projection.distance,
          routeDistance: app.routeDistances[i - 1] + segmentDistance * projection.ratio
        };
      }
    }
    return best;
  }

  function updateUserPosition(point) {
    if (!isInServiceArea(point)) {
      elements.trackState.textContent = "対象エリア外";
      setStatus("現在地は西新井駅から半径20kmの対象エリア外です。");
      return;
    }
    setMarker("user", point, "user-marker", "●");
    const nearest = findNearestRoutePoint(point);
    const total = app.routeDistances.at(-1) || 1;
    const progress = Math.max(0, Math.min(100, nearest.routeDistance / total * 100));
    const onRoute = nearest.distance <= ROUTE_THRESHOLD_METERS;

    elements.trackingCard.classList.toggle("ok", onRoute);
    elements.trackingCard.classList.toggle("danger", !onRoute);
    elements.onRoute.textContent = onRoute ? "コース上にいます" : "コースから離れています";
    elements.nearestDistance.textContent = `コースまで約${Math.round(nearest.distance)}m`;
    elements.progressBar.style.width = `${progress.toFixed(1)}%`;
    elements.progressLabel.textContent = `推定進捗 ${progress.toFixed(1)}%`;
  }

  function startTracking() {
    if (!navigator.geolocation) {
      setStatus("このブラウザでは位置情報を利用できません。");
      return;
    }
    if (!window.isSecureContext) {
      setStatus("リアルタイム現在地判定にはHTTPSが必要です。ACM証明書を設定してHTTPS化してください。");
      return;
    }
    if (app.watchId !== null) {
      navigator.geolocation.clearWatch(app.watchId);
      app.watchId = null;
      app.lastTrackAt = 0;
      app.lastTrackPoint = null;
      elements.track.textContent = "リアルタイム判定を開始";
      elements.trackState.textContent = "停止中";
      return;
    }
    app.watchId = navigator.geolocation.watchPosition((position) => {
      const point = { lat: position.coords.latitude, lng: position.coords.longitude };
      const now = Date.now();
      const elapsed = now - app.lastTrackAt;
      const moved = app.lastTrackPoint ? haversine(app.lastTrackPoint, point) : Infinity;
      if (elapsed < TRACK_MIN_INTERVAL_MS && moved < TRACK_MIN_MOVE_METERS) return;
      app.lastTrackAt = now;
      app.lastTrackPoint = point;
      updateUserPosition(point);
      elements.trackState.textContent = "判定中";
    }, (error) => {
      setStatus(`現在地を取得できません: ${error.message}`);
      elements.trackState.textContent = "取得失敗";
    }, {
      enableHighAccuracy: true,
      maximumAge: 3000,
      timeout: 10000
    });
    elements.track.textContent = "リアルタイム判定を停止";
    setStatus("現在地判定を開始しました。端末の位置情報許可を確認してください。");
  }

  function locateUser() {
    if (!navigator.geolocation) {
      setStatus("このブラウザでは位置情報を利用できません。");
      return;
    }
    if (!window.isSecureContext) {
      setStatus("HTTP環境では現在地を取得できません。地図中心をスタートにするか、HTTPS化してください。");
      return;
    }
    setStatus("現在地を取得しています。");
    navigator.geolocation.getCurrentPosition((position) => {
      const point = { lat: position.coords.latitude, lng: position.coords.longitude };
      if (setStart(point, true)) {
        setStatus("現在地をスタートに設定しました。目的地を地図上でクリックしてください。");
      }
    }, (error) => {
      setStatus(`現在地を取得できません: ${error.message}`);
    }, {
      enableHighAccuracy: true,
      maximumAge: 5000,
      timeout: 10000
    });
  }

  function initMap() {
    if (!window.L) {
      setStatus("地図ライブラリを読み込めませんでした。ネットワーク接続を確認してください。");
      return;
    }
    const serviceAreaBounds = L.latLngBounds(
      [35.5970, 139.5680],
      [35.9570, 140.0135]
    );
    app.map = L.map("map", {
      zoomControl: false,
      preferCanvas: true,
      minZoom: 11,
      maxBounds: serviceAreaBounds,
      maxBoundsViscosity: 1
    }).setView(NISHIARAI_CENTER, 12);
    L.control.zoom({ position: "bottomleft" }).addTo(app.map);
    app.tileLayer = L.tileLayer("https://cyberjapandata.gsi.go.jp/xyz/std/{z}/{x}/{y}.png", {
      maxZoom: 18,
      keepBuffer: 1,
      updateWhenIdle: true,
      updateWhenZooming: false,
      attribution: '<a href="https://maps.gsi.go.jp/development/ichiran.html">国土地理院</a>'
    }).addTo(app.map);
    app.tileLayer.once("load", () => elements.mapLoading.classList.add("hidden"));
    window.setTimeout(() => {
      app.map.invalidateSize({ pan: false });
    }, 250);
    window.setTimeout(() => app.map.invalidateSize({ pan: false }), 900);
    window.setTimeout(() => elements.mapLoading.classList.add("hidden"), 4000);
    app.map.on("click", (event) => {
      if (setGoal({ lat: event.latlng.lat, lng: event.latlng.lng })) {
        setStatus("目的地を設定しました。コースを作成できます。");
      }
    });
    setStart(NISHIARAI_CENTER);
  }

  elements.locate.addEventListener("click", locateUser);
  elements.useCenter.addEventListener("click", () => {
    const center = app.map.getCenter();
    if (setStart({ lat: center.lat, lng: center.lng })) {
      setStatus("地図中心をスタート地点に設定しました。目的地をクリックしてください。");
    }
  });
  elements.sample.addEventListener("click", () => {
    setStart(NISHIARAI_CENTER, true);
    setGoal(TONERI_PARK);
    setStatus("西新井駅付近から舎人公園までのサンプル地点を設定しました。コースを作成できます。");
  });
  elements.build.addEventListener("click", buildRoute);
  elements.track.addEventListener("click", startTracking);

  window.addEventListener("resize", () => {
    if (app.elevations.length) drawElevationChart(app.elevations);
    app.map?.invalidateSize({ pan: false });
  });

  initMap();
  drawEmptyChart("ルート作成後に高低差を表示します");
  syncControls();
})();
