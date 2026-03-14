import { LuaFactory } from 'wasmoon';

const SCREEN_WIDTH = 320;
const SCREEN_HEIGHT = 240;

class PICO16Runtime {
    constructor() {
        this.canvas = document.getElementById('pico-canvas');
        this.ctx = this.canvas.getContext('2d', { alpha: false });
        this.ctx.imageSmoothingEnabled = false;
        
        this.palette = this.initPalette();
        this.mouse = { x: 0, y: 0, b: false };
        this.lua = null;
        this.isRunning = false;
        
        this.setupEvents();
        this.boot();
    }

    initPalette() {
        const colors = [
            [10, 10, 15], [180, 50, 20], [255, 100, 50], [0, 80, 40],
            [100, 80, 150], [80, 80, 80], [150, 150, 150], [240, 240, 255],
            [255, 0, 77], [255, 163, 0], [255, 236, 39], [0, 228, 54],
            [157, 0, 255], [41, 173, 255], [131, 118, 156], [255, 119, 168]
        ];
        return colors.map(c => `rgb(${c[0]},${c[1]},${c[2]})`);
    }

    setupEvents() {
        this.canvas.addEventListener('mousemove', (e) => {
            const rect = this.canvas.getBoundingClientRect();
            this.mouse.x = Math.floor((e.clientX - rect.left) / (rect.width / SCREEN_WIDTH));
            this.mouse.y = Math.floor((e.clientY - rect.top) / (rect.height / SCREEN_HEIGHT));
        });
        this.canvas.addEventListener('mousedown', () => this.mouse.b = true);
        this.canvas.addEventListener('mouseup', () => this.mouse.b = false);
        document.getElementById('reset-btn').onclick = () => this.boot();
    }

    log(msg, type='info') {
        const out = document.getElementById('console-output');
        if (!out) return;
        const p = document.createElement('p');
        p.className = `log-${type}`;
        p.innerText = `> ${msg}`;
        out.appendChild(p);
        out.scrollTop = out.scrollHeight;
    }

    async boot() {
        this.log("VM: Initializing WASM Core...", "warn");
        this.isRunning = false;
        
        try {
            const factory = new LuaFactory();
            this.lua = await factory.createEngine();

            // Register API
            this.lua.global.set('cls', (c) => {
                this.ctx.fillStyle = this.palette[c] || '#000';
                this.ctx.fillRect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT);
            });

            this.lua.global.set('spr', (n, x, y, w = 1, h = 1) => {
                this.ctx.fillStyle = n === 16 ? '#9d00ff' : '#ffffff';
                this.ctx.fillRect(x, y, w * 8, h * 8);
                if (n === 16) {
                    this.ctx.shadowBlur = 10;
                    this.ctx.shadowColor = '#9d00ff';
                    this.ctx.fillRect(x, y, 8, 8);
                    this.ctx.shadowBlur = 0;
                }
            });

            this.lua.global.set('print', (s, x, y, c = 7) => {
                this.ctx.fillStyle = this.palette[c];
                this.ctx.font = '8px "Space Mono"';
                this.ctx.fillText(s, x, y + 8);
            });

            this.lua.global.set('stat', (i) => {
                if (i === 32) return this.mouse.x;
                if (i === 33) return this.mouse.y;
                return 0;
            });

            this.lua.global.set('btnp', () => this.mouse.b);

            this.lua.global.set('rectfill', (x1, y1, x2, y2, c) => {
                this.ctx.fillStyle = this.palette[c];
                this.ctx.fillRect(x1, y1, x2 - x1, y2 - y1);
            });

            this.lua.global.set('t', () => Date.now() / 1000);
            this.lua.global.set('flr', Math.floor);
            this.lua.global.set('abs', Math.abs);
            this.lua.global.set('sin', Math.sin);
            this.lua.global.set('lerp', (a, b, t) => a + (b - a) * t);
            
            // Utility placeholders
            this.lua.global.set('map_draw', () => {});
            this.lua.global.set('add', (t, v) => t[Object.keys(t).length + 1] = v);

            this.log("VM: Loading Xeno-Crossing.lua...");
            const response = await fetch('/Xeno-Crossing.lua');
            const code = await response.text();
            
            await this.lua.doString(code);

            this.log("VM: Initializing Mars Environment...");
            if (this.lua.global.get('_init')) {
                await this.lua.global.call('_init');
            }

            this.isRunning = true;
            this.log("VM: RUNTIME ACTIVE (WASM).", "info");
            this.loop();
        } catch (e) {
            this.log(`BOOT FAILED: ${e.message}`, "err");
            console.error(e);
        }
    }

    loop() {
        if (!this.isRunning) return;

        try {
            if (this.lua.global.get('_update')) {
                this.lua.global.call('_update');
            }
            if (this.lua.global.get('_draw')) {
                this.lua.global.call('_draw');
            }
        } catch (e) {
            this.log(`RUNTIME ERROR: ${e.message}`, "err");
            this.isRunning = false;
        }

        requestAnimationFrame(() => this.loop());
    }
}

new PICO16Runtime();
