import { Container } from "@cloudflare/containers";
import { Hono } from "hono";
import { basicAuth } from 'hono/basic-auth'


export class Sandbox extends Container {
  // Port the container listens on (default: 8080)
  defaultPort = 8080;
  // Time before container sleeps due to inactivity (default: 30s)
  sleepAfter = "2m";
  // Environment variables passed to the container
  envVars = {
    MESSAGE: "I was passed in via the container class!",
  };
  // Disable auto-start on fetch
  manualStart = true;

  checkIfRunning() {
    return this.ctx.container?.running ?? false;
  }

  // Optional lifecycle hooks
  override onStart() {
    console.log("Container successfully started");
  }

  override onStop() {
    console.log("Container successfully shut down");
  }

  override onError(error: unknown) {
    console.log("Container error:", error);
  }
}

// Create Hono app with proper typing for Cloudflare Workers
const app = new Hono<{
  Bindings: { SANDBOX_CONTAINERS: DurableObjectNamespace<Sandbox>, HOSTNAME_PATTERN: string };
}>();

// Project admin endpoints with auth
app.use(
  '/admin/*',
  basicAuth({
    username: 'cf',
    password: 'testing',
  })
)

// Home route with available endpoints
app.get("/help", (c) => {
  return c.text(
    "Available endpoints:\n" +
      "GET /container/<ID> - Fetch to the container using the container ID\n" +
      "POST /admin/container/<ID>/start - Start a container for each ID with a 2m timeout\n" +
      "POST /admin/container/<ID>/stop - Stop a container for each ID\n" +
      "POST /admin/container/<ID>/update-text - Update the text in the container\n"
  );
});

// Start a container using the container ID
app.post("/admin/container/:id/start", async (c) => {
  const SUPPORTED_LOCATIONS: Record<string, DurableObjectLocationHint> = {
    wnam: "wnam",
    enam: "enam",
    sam: "sam",
    weur: "weur",
    eeur: "eeur",
    apac: "apac",
    oc: "oc",
    afr: "afr",
    me: "me"
  };
  const body = await c.req.json()
  const location = body.location as string | undefined;
  // Check if location is valid
  if (location &&  !SUPPORTED_LOCATIONS[location]) {
    return c.json({ error: "Invalid location" }, 400);
  }
  
  
  const id = c.req.param("id");
  const containerId = c.env.SANDBOX_CONTAINERS.idFromName(`/container/${id}`);
  let container = undefined;
  if (location) {
     container = c.env.SANDBOX_CONTAINERS.get(containerId, {locationHint: SUPPORTED_LOCATIONS[location]});
  } else {
   container = c.env.SANDBOX_CONTAINERS.get(containerId);
  }

  // Check if already running
  if (await container.checkIfRunning()) {
    return c.json({ error: "Container is already running" }, 400);
  }

  await container.start();
  const sandboxUrl = c.env.HOSTNAME_PATTERN.replace("<CONTAINER_ID>", id);
  return c.json({ message: "Container started successfully", sandboxUrl });
});

// Stop a container using the container ID
app.post("/admin/container/:id/stop", async (c) => {
  const id = c.req.param("id");
  const containerId = c.env.SANDBOX_CONTAINERS.idFromName(`/container/${id}`);
  const container = c.env.SANDBOX_CONTAINERS.get(containerId);

  // Check if already running
  if (!await container.checkIfRunning()) {
    return c.json({ error: "Container is not running" }, 400);
  }

  await container.stop();
  return c.json({ message: "Container stopped successfully" });
});

// Update sandbox container using the container ID
app.post("/admin/container/:id/update-text", async (c) => {
  const id = c.req.param("id");
  const containerId = c.env.SANDBOX_CONTAINERS.idFromName(`/container/${id}`);
  const container = c.env.SANDBOX_CONTAINERS.get(containerId);
 
  // Overwriting path to remove container references
  return await container.fetch("http://localhost/admin-private/update-text",c.req.raw);
});




// Route requests to a specific container using the container ID
app.get("*", async (c) => {

  // Get container ID from hostname
  const req = c.req.raw
  const url = new URL(req.url)
  const hostname = url.hostname
  const id = hostname.split(".")[0]
  const containerId = c.env.SANDBOX_CONTAINERS.idFromName(`/container/${id}`);
  const container = c.env.SANDBOX_CONTAINERS.get(containerId);

  // Check if container is running
  if (!await container.checkIfRunning()) {
    return c.json({ error: "Container is not running" }, 400);
  }

  // Check if it's private endpoint - should only be allowed via admin endpoints with auth
  if (c.req.path.startsWith("/admin-private/")) {
    return c.json({ error: "No permission" }, 401);
  }
  // Proxy request to container
  return await container.fetch(req);
});




export default app;
