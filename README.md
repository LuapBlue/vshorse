# Docker Services Prototype

## What is this?
This project runs multiple web services on your Mac using Docker. Think of it as a collection of development tools that work together.

## What you'll need on your Mac

1. **Docker Desktop for Mac**
   - Download from: https://www.docker.com/products/docker-desktop/
   - After downloading, open the .dmg file and drag Docker to your Applications folder
   - Open Docker from your Applications folder and wait for it to start (you'll see a whale icon in your menu bar)

2. **Node.js** (for running the project commands)
   - Download from: https://nodejs.org/
   - Choose the "LTS" version (the recommended one)
   - Open the downloaded .pkg file and follow the installation steps

3. **A Terminal app**
   - You already have this! Find "Terminal" in your Applications > Utilities folder
   - Or press Command + Space, type "Terminal", and press Enter

## Getting Started

1. **Open Terminal**

   - Navigate to this project on your local machine

2. **Install project dependencies**

   - In Terminal, type:

     ```
     npm install
     ```
     
   - Press Enter and wait for it to finish (this may take a few minutes)

3. **Install Playwright (for testing)**
   - Type:
     ```
     npx playwright install
     ```
   - Press Enter

4. **Start all services**
   - Type:
     ```
     npm start
     ```
   - Press Enter
   - Wait for the message "Setup complete!"

## Using the Services

Once everything is running, you can access these tools in your web browser:

- **Supabase Studio** (Database management): http://localhost:3000
- **Trigger.dev** (Background job processing): http://localhost:8031
- **VSCode** (Code editor in your browser): http://localhost:8444
- **Socket.io** (Real-time communication): http://localhost:3020
- **Traefik Dashboard** (Service routing): http://localhost:8081

Just click on any of these links or copy and paste them into your browser.

## Common Commands

In Terminal, while in the project folder:

- **Stop all services**: `npm stop`
- **Build the project**: `npm run build`
- **Run tests**: `npm test`
- **Check code quality**: `npm run lint`

## Troubleshooting

### "Command not found" errors
- Make sure you've installed Node.js and Docker Desktop
- Restart Terminal after installing

### Services won't start
- Make sure Docker Desktop is running (look for the whale icon in your menu bar)
- Try stopping everything first: `npm stop`
- Then start again: `npm start`

### "Port already in use" errors
- Another program is using the same network port
- Try: `npm stop` to stop all services
- If that doesn't work, restart Docker Desktop

### Not enough memory
- Docker needs at least 8GB of RAM
- Open Docker Desktop settings (click the whale icon > Settings)
- Go to Resources and increase the Memory slider

## Need Help?

If something isn't working:
1. Make sure Docker Desktop is running
2. Try `npm stop` then `npm start`
3. Check that no other programs are using the same ports (3000, 8000, etc.)

## What's Next?

Once everything is running, you can:
- Explore the web interfaces linked above
- Write your own TypeScript code in the `src` folder
- Run tests with `npm test`
- Build your project with `npm run build`
