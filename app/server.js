const http = require("http");
const os = require("os");

const PORT = process.env.PORT || 3000;

const server = http.createServer((req, res) => {

    // Endpoint de salud para Consul
    if (req.url === "/health") {
        res.writeHead(200, {
            "Content-Type": "text/plain; charset=utf-8"
        });

        res.end("OK");
        return;
    }

    // Página principal
    res.writeHead(200, {
        "Content-Type": "text/html; charset=utf-8"
    });

    res.end(`
        <!DOCTYPE html>
        <html lang="es">

        <head>
            <meta charset="UTF-8">
            <title>Microproyecto Cloud</title>
        </head>

        <body>

            <h1>Microproyecto - Computación en la Nube</h1>

            <h2>Servidor que respondió:</h2>

            <p>
                <strong>${os.hostname()}</strong>
            </p>

            <p>
                Puerto: ${PORT}
            </p>

            <p>
                Balanceo de carga con HAProxy + Consul
            </p>

        </body>

        </html>
    `);
});

server.listen(PORT, "0.0.0.0", () => {
    console.log(
        `Servidor ${os.hostname()} ejecutándose en el puerto ${PORT}`
    );
});