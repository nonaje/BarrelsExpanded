# Barrels Expanded [MP + SP]

![Barrels Expanded](preview.png)

> Un mod para Project Zomboid que le da vida a los barriles del mundo — asignándoles contenido aleatorio, estado persistente e interacciones jugables tanto en singleplayer como en multijugador.

---

## ¿Por qué se creó?

El mundo de Project Zomboid está lleno de barriles industriales y militares, pero siempre han sido simples decoraciones estáticas. Se podían ver, rodear, pero nunca interactuar con ellos de forma significativa.

**Barrels Expanded** nació para cambiar eso. La idea es simple: esos barriles deberían sentirse como parte del mundo. Quizás uno está lleno de gasolina que dejó atrás un trabajador de fábrica. Quizás otro tiene agua acumulada en un viejo campamento militar. No lo sabrás hasta que lo abras.

El objetivo es agregar profundidad e imprevisibilidad a la exploración sin modificar el juego drásticamente — solo pequeñas interacciones inmersivas que hacen que el mundo se sienta más vivo.

---

## ¿Qué hace?

El mod añade comportamiento interactivo a los barriles que ya existen en el mundo del juego (tiles vanilla). Cuando te acercas a un barril e interactúas con él por primera vez, lo fuerzas con una herramienta — y descubres qué hay dentro.

El contenido se **genera aleatoriamente** en el momento de abrirlo:
- El tipo de líquido (Combustible o Agua)
- La cantidad almacenada (entre 1 y 160 unidades)

Una vez abierto, el estado del barril **queda guardado permanentemente** en el mundo, por lo que el contenido persiste entre sesiones y es compartido entre todos los jugadores en multijugador.

---

## ¿Cómo funciona?

El mod sigue una arquitectura **cliente–servidor** limpia:

1. **Detección:** Al hacer clic derecho sobre un tile de barril compatible en el mundo, el menú contextual lo detecta y muestra un submenú *"Barril"*.
2. **Verificación de herramientas:** Antes de poder abrirlo, el juego verifica si el jugador lleva al menos una de las herramientas requeridas.
3. **Solicitud:** Al confirmar la acción, el cliente envía un comando de red al servidor.
4. **Generación:** El servidor genera aleatoriamente el tipo de líquido y el nivel de llenado, y guarda el resultado en el `modData` del objeto.
5. **Sincronización:** El servidor transmite los datos a todos los clientes mediante `transmitModData()`, manteniendo la vista de todos los jugadores consistente.
6. **Persistencia:** Los datos generados están vinculados a la posición del barril en el mundo y a su índice de objeto, por lo que sobreviven a los guardados y reinicios del servidor.

En la interfaz, se muestra un **tooltip detallado** en la opción del menú contextual con el tipo de líquido y el nivel de llenado una vez que el barril ha sido abierto.

---

## Funcionalidades actuales

| Funcionalidad | Detalles |
|---|---|
| **Soporte para SP y MP** | Compatible completo con singleplayer y multijugador |
| **Interacción con barriles del mundo** | Interactúa con tiles de barriles vanilla en zonas industriales y militares |
| **Contenido aleatorio** | El tipo de líquido y la cantidad se asignan aleatoriamente al abrir por primera vez |
| **Tipos de líquido** | Combustible y Agua |
| **Capacidad del barril** | 160 unidades, con llenado aleatorio (1–160) |
| **Herramientas requeridas** | Cualquiera de: Palanca, Palanca Forjada, Destornillador, Llave de Tubería, o Tijeras de Chapa |
| **Tooltips detallados** | Muestra tipo de líquido y cantidad/capacidad tras abrir |
| **Estado persistente** | El contenido se guarda con el mundo y es compartido entre todos los jugadores |
| **Tiles de barriles soportados** | Barriles industriales, barriles de campamentos militares y barriles artesanales |

---

## Funcionalidades planeadas

- [ ] **Acción "Quitar tapa"** — Quitar físicamente la tapa del barril como paso previo antes de acceder al contenido
- [ ] **Transferir líquido** — Verter el contenido del barril en bidones, botellas u otros recipientes
- [ ] **Llenar barriles** — Rellenar un barril vacío con líquido proveniente de recipientes u otras fuentes
- [ ] **Más tipos de líquido** — Lejía, alcohol, aceite y otros líquidos con sentido en el mundo del juego
- [ ] **Condición del barril** — Los barriles pueden estar oxidados o dañados, afectando la calidad de su contenido
- [ ] **Barriles artesanales** — Colocar y configurar tus propios barriles en el mundo
- [ ] **Lista de herramientas ampliada** — Herramientas adicionales que puedan usarse para abrir barriles

---

## Compatibilidad

- **Versión del juego:** Build 42
- **Multijugador:** ✅ Totalmente compatible
- **Singleplayer:** ✅ Totalmente compatible
- **Solo servidor:** ❌ No compatible (el mod debe estar activo en el cliente)

---

## Instalación

1. Suscríbete al mod en Steam Workshop.
2. Actívalo desde el menú **Mods** en el menú principal o al crear una nueva partida.
3. No se necesita configuración adicional.

---

*[English 🇬🇧](README.md)*
