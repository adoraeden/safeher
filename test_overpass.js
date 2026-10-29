
const [latText, lonText, radiusText] = process.argv.slice(2);

const latitude = Number(latText);
const longitude = Number(lonText);
const radius = radiusText ? Number(radiusText) : 5000;

if (
  !latText ||
  !lonText ||
  !Number.isFinite(latitude) ||
  !Number.isFinite(longitude) ||
  latitude < -90 ||
  latitude > 90 ||
  longitude < -180 ||
  longitude > 180 ||
  !Number.isFinite(radius) ||
  radius < 100 ||
  radius > 50000
) {
  console.error(
    'Usage: node test_overpass.js <latitude> <longitude> [radius-meters]'
  );
  process.exit(1);
}

const query = `
[out:json][timeout:10];
(
  nwr["amenity"~"^(police|hospital)$"]
  (around:${radius},${latitude},${longitude});
);
out center 20;
`;

const endpoints = [
  'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
  'https://overpass.private.coffee/api/interpreter',
  'https://overpass-api.de/api/interpreter',
];

async function test() {
  let validResponse = false;

  for (const endpoint of endpoints) {
    console.log('\nTesting:', endpoint);

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 12000);

    try {
      const start = Date.now();

      const response = await fetch(endpoint, {
        method: 'POST',
        headers: {
          'User-Agent': 'SafeHer-Overpass-Diagnostic/1.0',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: new URLSearchParams({ data: query }).toString(),
        signal: controller.signal,
      });

      const body = await response.text();

      console.log('HTTP status:', response.status);
      console.log('Response time:', Date.now() - start, 'ms');

      if (!response.ok) {
        console.log('Endpoint returned an error:', body.slice(0, 200));
        continue;
      }

      let data;

      try {
        data = JSON.parse(body);
      } catch {
        console.log('Response was not valid JSON.');
        continue;
      }

      if (!Array.isArray(data.elements)) {
        console.log('Response has no elements array.');
        continue;
      }

      validResponse = true;
      console.log('Valid response. Places found:', data.elements.length);

      for (const place of data.elements.slice(0, 5)) {
        console.log(
          '-',
          place.tags?.name || '(unnamed place)',
          '|',
          place.tags?.amenity || 'unknown type'
        );
      }
    } catch (error) {
      console.log('Request failed:', error.message);
    } finally {
      clearTimeout(timeout);
    }
  }

  if (!validResponse) {
    console.error('\nNo endpoint returned valid Overpass data.');
    process.exitCode = 1;
  }
}

test();
