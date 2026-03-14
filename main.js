import { LuaFactory } from 'wasmoon';

const SCREEN_WIDTH = 320;
const SCREEN_HEIGHT = 240;

class PICO16Runtime {
    constructor() {
        this.canvas = document.getElementById('pico-canvas');
        this.ctx = this.canvas.getContext('2d', { alpha: false });
        this.ctx.imageSmoothingEnabled = false;
        
        this.palette = this.initPalette();
        this.mouse = { x: 0, y: 0, bLeft: false, bRight: false };
        this.lua = null;
        this.isRunning = false;
        
        // Sprite Sheet Data (8x8 pixels)
        this.sprites = {
            1: [ // Nomad Rover
                0,0,1,1,1,1,0,0,
                0,1,9,9,9,9,1,0,
                1,9,9,9,12,9,9,1,
                1,9,12,12,12,12,9,1,
                1,9,9,9,9,9,9,1,
                0,1,1,1,1,1,1,0,
                0,0,5,5,5,5,0,0,
                0,0,5,5,5,5,0,0
            ],
            2: [ // Anchor Seed
                0,0,0,7,7,0,0,0,
                0,0,7,7,7,7,0,0,
                0,7,7,7,7,7,7,0,
                0,7,7,7,7,7,7,0,
                0,0,7,11,11,7,0,0,
                0,11,11,11,11,11,11,0,
                0,11,0,11,11,0,11,0,
                11,0,0,11,11,0,0,11
            ],
            3: [ // Wraith Oracle
                0,0,0,5,5,0,0,0,
                0,13,13,5,5,13,13,0,
                13,13,5,13,13,5,13,13,
                13,13,13,12,12,13,13,13,
                0,13,13,12,12,13,13,0,
                0,0,13,13,13,13,0,0,
                0,13,0,0,0,0,13,0,
                0,0,0,0,0,0,0,0
            ],
            4: [ // Dust Devil
                0,0,8,8,8,8,0,0,
                0,8,8,8,8,8,8,0,
                8,8,0,8,8,0,8,8,
                8,8,8,8,8,8,8,8,
                0,8,0,8,8,0,8,0,
                0,0,8,8,8,8,0,0,
                0,8,0,8,8,0,8,0,
                8,0,0,8,8,0,0,8
            ],
            5: [ // Cursor
                0,0,0,7,7,0,0,0,
                0,0,0,7,7,0,0,0,
                0,0,0,0,0,0,0,0,
                7,7,0,0,0,0,7,7,
                7,7,0,0,0,0,7,7,
                0,0,0,0,0,0,0,0,
                0,0,0,7,7,0,0,0,
                0,0,0,7,7,0,0,0
            ],
            6: [ // Outpost (Tiny Base)
                0,0,0,1,1,0,0,0,
                0,0,1,6,6,1,0,0,
                0,1,6,7,7,6,1,0,
                1,6,7,7,7,7,6,1,
                1,6,7,7,7,7,6,1,
                1,1,1,1,1,1,1,1,
                0,1,1,1,1,1,1,0,
                0,0,0,0,0,0,0,0
            ]
        };

        this.setupEvents();
        this.setupAudio();
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
        this.canvas.addEventListener('mousedown', (e) => {
            if (e.button === 0) this.mouse.bLeft = true;
            if (e.button === 2) this.mouse.bRight = true;
        });
        this.canvas.addEventListener('mouseup', (e) => {
            if (e.button === 0) this.mouse.bLeft = false;
            if (e.button === 2) this.mouse.bRight = false;
        });
        this.canvas.addEventListener('contextmenu', (e) => e.preventDefault());
        document.getElementById('reset-btn').onclick = () => this.boot();
    }

    setupAudio() {
        this.audioCtx = new (window.AudioContext || window.webkitAudioContext)();
    }

    playSfx(type) {
        if (!this.audioCtx) return;
        if (this.audioCtx.state === 'suspended') this.audioCtx.resume();
        
        const osc = this.audioCtx.createOscillator();
        const gain = this.audioCtx.createGain();
        osc.connect(gain);
        gain.connect(this.audioCtx.destination);
        
        const now = this.audioCtx.currentTime;
        
        if (type === 'gather') {
            osc.type = 'square';
            osc.frequency.setValueAtTime(220, now);
            osc.frequency.exponentialRampToValueAtTime(110, now + 0.1);
            gain.gain.setValueAtTime(0.1, now);
            gain.gain.linearRampToValueAtTime(0, now + 0.1);
        } else if (type === 'attack') {
            osc.type = 'triangle';
            osc.frequency.setValueAtTime(880, now);
            osc.frequency.exponentialRampToValueAtTime(440, now + 0.05);
            gain.gain.setValueAtTime(0.1, now);
            gain.gain.linearRampToValueAtTime(0, now + 0.05);
        } else if (type === 'damage') {
            osc.type = 'sawtooth';
            osc.frequency.setValueAtTime(110, now);
            osc.frequency.linearRampToValueAtTime(55, now + 0.2);
            gain.gain.setValueAtTime(0.2, now);
            gain.gain.linearRampToValueAtTime(0, now + 0.2);
        }
        
        osc.start();
        osc.stop(now + 0.2);
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
        this.log("VM: Initializing WAR CORE...", "warn");
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
                const sprite = this.sprites[n];
                if (!sprite) {
                    this.ctx.fillStyle = '#ff00ff';
                    this.ctx.fillRect(x, y, w*8, h*8);
                    return;
                }
                
                // Simplified single sprite draw
                for(let i=0; i<64; i++) {
                    const col = sprite[i];
                    if (col !== 0) { // Transparency
                        this.ctx.fillStyle = this.palette[col];
                        const px = x + (i % 8);
                        const py = y + Math.floor(i / 8);
                        this.ctx.fillRect(px, py, 1, 1);
                    }
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
                if (i === 34) return this.mouse.bRight ? 1 : 0;
                return 0;
            });

            this.lua.global.set('btnp', (i) => {
                if (i === 4) return this.mouse.bLeft;
                return false;
            });

            this.lua.global.set('rectfill', (x1, y1, x2, y2, c) => {
                this.ctx.fillStyle = this.palette[c];
                this.ctx.fillRect(x1, y1, x2 - x1, y2 - y1);
            });

            this.lua.global.set('line', (x1, y1, x2, y2, c) => {
                this.ctx.strokeStyle = this.palette[c];
                this.ctx.lineWidth = 1;
                this.ctx.beginPath();
                this.ctx.moveTo(x1, y1);
                this.ctx.lineTo(x2, y2);
                this.ctx.stroke();
            });

            this.lua.global.set('sfx', (type) => this.playSfx(type));
            this.lua.global.set('t', () => Date.now() / 1000);
            this.lua.global.set('flr', Math.floor);
            this.lua.global.set('abs', Math.abs);
            this.lua.global.set('sin', Math.sin);
            this.lua.global.set('cos', Math.cos);
            this.lua.global.set('sqrt', Math.sqrt);
            this.lua.global.set('rnd', (n = 1) => Math.random() * n);
            this.lua.global.set('lerp', (a, b, t) => a + (b - a) * t);
            this.lua.global.set('dist', (x1, y1, x2, y2) => Math.sqrt((x2-x1)**2 + (y2-y1)**2));
            
            // Utility placeholders
            this.lua.global.set('map_draw', () => {});

            this.log("VM: Loading WAR CART...");
            const response = await fetch('/Xeno-Crossing.lua');
            const code = await response.text();
            
            await this.lua.doString(code);

            if (this.lua.global.get('_init')) {
                await this.lua.global.call('_init');
            }

            this.isRunning = true;
            this.log("VM: WAR RUNTIME ACTIVE.", "info");
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
