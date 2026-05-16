# Barrels Expanded [MP + SP]

![Barrels Expanded](preview.png)

> Un mod para Project Zomboid que le da vida a los barriles del mundo, asignandoles contenido aleatorio, estado persistente e interacciones jugables tanto en singleplayer como en multijugador.

---

## Por que se creo?

El mundo de Project Zomboid esta lleno de barriles industriales y militares, pero normalmente son decoracion estatica. Se pueden ver, pero no usar de forma significativa.

**Barrels Expanded** nace para cambiar eso. La idea es simple: los barriles deben sentirse parte del mundo. Uno puede tener gasolina dejada por un trabajador. Otro puede contener agua de lluvia acumulada en un campamento militar. No lo sabes hasta abrirlo.

El objetivo es agregar profundidad e imprevisibilidad a la exploracion sin modificar el juego de forma drastica.

---

## Que hace?

El mod agrega comportamiento interactivo a barriles vanilla del mundo. Puedes:

- Abrir e inspeccionar barriles.
- Beber desde el barril (si el liquido es bebible).
- Lavarte o lavar ropa usando agua del barril.
- Verter liquido al barril.
- Extraer liquido del barril.
- Vaciar barriles.

El contenido del barril se genera en la primera apertura:

- Tipo de liquido: Agua, Agua Contaminada, Gasolina o Lejia.
- Cantidad: entre 1 y 160 unidades.

Una vez generado, el estado queda guardado en datos del mundo y compartido en multiplayer.

---

## Como funciona?

El mod sigue una arquitectura cliente-servidor:

1. **Deteccion:** El menu contextual detecta tiles compatibles y muestra el submenu Barril.
2. **Solicitud:** El cliente envia la accion al servidor.
3. **Validacion:** El servidor valida distancia, herramientas, identidad de item y compatibilidad de liquidos.
4. **Mutacion:** El servidor aplica los cambios reales de estado (beber/lavar/transferir/vaciar).
5. **Sincronizacion:** El servidor actualiza clientes via `transmitModData()` y mensajes de red.
6. **Persistencia:** Los datos del barril sobreviven guardados y reinicios del servidor.

---

## Funciones existentes

1. **Abrir barril** con una herramienta requerida: Palanca, Palanca Forjada, Destornillador, Llave de Tuberia o Tijeras de Chapa.
2. **Inspeccionar informacion del barril** mediante tooltips contextuales (tipo de liquido, nivel, requisitos y razones de deshabilitado).
3. **Beber del barril** (Agua y Agua Contaminada).
4. **Lavar desde barril**:
   - Lavado del personaje.
   - Lavado de ropa y objetos lavables.
   - El jabon es opcional, pero cambia la velocidad.
5. **Verter al barril** desde recipientes compatibles del inventario (requiere Embudo).
6. **Extraer del barril** hacia recipientes compatibles del inventario (requiere Manguera de Goma).
7. **Vaciar barril** completamente.
8. **Contenido aleatorio en primera apertura** segun categoria del tile.
9. **Estado persistente** guardado en `modData`.
10. **Multijugador server-authoritative** con locks de transferencia para evitar solapamientos en el mismo barril.
11. **Peso dinamico del barril** segun tipo y cantidad de liquido.
12. **Soporte singleplayer y multijugador**.

### Datos de juego

| Categoria | Estado actual |
|---|---|
| Tipos de liquido | Agua, Agua Contaminada, Gasolina, Lejia |
| Capacidad del barril | 160 unidades |
| Consumo por beber | 0.12 unidades por accion de beber |
| Costo por lavado | 1 unidad por segmento de cuerpo/item lavado |
| Tiles soportados | Barriles industriales, militares y crafteados |

---

## Funcionalidades planeadas

- [ ] **Flujo separado de tapa**: interaccion por etapas (quitar tapa vs abrir/inspeccionar).
- [ ] **Sistema de condicion del barril**: oxido/dano que afecte confiabilidad y calidad.
- [ ] **Opciones Sandbox**: perfiles de spawn, reglas de capacidad y ajustes de comportamiento.
- [ ] **Ecosistema de liquidos ampliado**: mas tipos de liquido con compatibilidad balanceada.

---

## Ideas futuras

- Recargar generadores desde barriles de gasolina.
- Recargar vehiculos desde barriles de gasolina.
- Transferir liquido entre barriles.
- Drenar combustible de vehiculos hacia barriles.
- Etiquetado y marcadores de propiedad para organizacion en MP.
- Interacciones de tratamiento de agua (por ejemplo, filtrar agua contaminada con pasos de gameplay).

---

## Compatibilidad

- **Version del juego:** Build 42
- **Multijugador:** Soportado
- **Singleplayer:** Soportado
- **Solo servidor:** No soportado (el mod debe estar activo en cliente)

---

## Instalacion

1. Suscribete al mod en Steam Workshop.
2. Activalo desde el menu **Mods** en el menu principal o al crear partida.
3. No requiere configuracion adicional.

---

*[English](README.md)*
