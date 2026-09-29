# Score Tracker para Xiaomi Smart Band 9

Marcador rápido para la muñeca: una app propia (Vela JS) para la Xiaomi Smart Band 9 que permite sumar puntos o goles a dos equipos con un toque, sin sacar el teléfono. No está pensada para un solo deporte: sirve para fútbol, pádel, básquet, juegos de cartas o cualquier cosa que lleve un marcador.

> Proyecto personal y en desarrollo. No está afiliado a Xiaomi.

## Estado

- [x] Marcador con dos botones (local / visita)
- [x] Probado en el emulador y en una Band 9 física
- [x] Vibración al sumar (declarada en el código; falta confirmarla en la banda real)
- [x] Hora actual
- [x] Deshacer el último punto
- [ ] Cronómetro
- [ ] Iniciar / pausar / finalizar / resetear

## Probado con

- Xiaomi Smart Band 9 (firmware global) y Mi Fitness desde Google Play
- Samsung Galaxy S25 (Android)
- macOS en Apple Silicon

Otros equipos pueden funcionar, pero no están verificados.

## Requisitos para desarrollar

- [AIoT-IDE](https://iot.mi.com/vela/quickapp/en/guide/start/use-ide.html) (descargalo solo desde el sitio oficial de Xiaomi)
- Node.js 16 o superior
- Para instalar en una banda real: ADB, JDK y el Android SDK (`build-tools` y `platforms`)

## Desarrollo

```bash
npm i --ignore-scripts
```

Abrí la carpeta en AIoT-IDE, creá un emulador de tipo banda (imagen Vela 4.0, 192×490) y ejecutá el proyecto con **Debug**.

`designWidth` está fijado en `192` en `src/manifest.json`, así que los tamaños del CSS están en píxeles reales de la pantalla de la Band 9.

## Instalar en tu propia Band 9

Xiaomi documenta la instalación de paquetes `.rpk` propios en un menú de depuración de Mi Fitness que **no aparece** en la versión normal de la app. Este proyecto usa el método no oficial del repositorio [oryonatan/xiaomi-band-development](https://github.com/oryonatan/xiaomi-band-development), que abre esa pantalla oculta por ADB.

**Es un método no oficial: puede dejar de funcionar con una actualización de Mi Fitness y lo usás bajo tu propia responsabilidad.**

Recomendaciones de seguridad:

- Leé los scripts de ese repositorio antes de ejecutarlos. Se ejecutan con permisos de shell de ADB en tu teléfono.
- Activá la depuración USB solo mientras desplegás y revocá las autorizaciones después.
- No uses versiones modificadas de Mi Fitness ni módulos de root.

Flujo:

1. Clonar `xiaomi-band-development` y revisar sus scripts.
2. Conectar el teléfono por USB, desbloquearlo y abrir Mi Fitness con la banda emparejada.
3. Ejecutar `./deploy-band.sh`. Sube el `versionCode`, compila, instala y limpia archivos temporales.
4. Elegir el `.rpk` en el selector de archivos del teléfono.

El script de terceros está pensado para el teclado de Samsung. Con otros teclados (por ejemplo Gboard) el tipeo automático del nombre del paquete puede fallar; en ese caso escribilo a mano.

## Estructura

```
src/
  manifest.json    configuración de la app (paquete, permisos, ruta)
  pages/           pantallas
deploy-band.sh     compilar e instalar en la banda física
```

## Créditos

- Método de instalación: [oryonatan/xiaomi-band-development](https://github.com/oryonatan/xiaomi-band-development)
- Documentación de Vela JS: [iot.mi.com/vela](https://iot.mi.com/vela/quickapp/en/)

## Licencia

MIT (ver `LICENSE`).