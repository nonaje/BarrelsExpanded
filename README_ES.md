# Barrels Expanded [MP + SP]

![Barrels Expanded](preview.png)

> Un mod para Project Zomboid Build 42 que convierte los barriles del mundo en recursos utiles de supervivencia con contenido aleatorio, estado persistente e interacciones jugables para singleplayer y multiplayer.

---

## Por que se creo?

El mundo de Project Zomboid esta lleno de barriles industriales y militares, pero la mayoria son solo escenografia. Puedes pasar al lado, construir alrededor o ignorarlos, pero casi nunca importan.

**Barrels Expanded** cambia eso. Los barriles pueden convertirse en agua de emergencia, reservas de gasolina, suministros de limpieza o contenedores vacios para usar en tu base. No sabes que hay dentro hasta abrir uno.

El objetivo es hacer que la exploracion sea mas interesante sin convertir el juego en otra cosa.

---

## Que hace?

El mod agrega comportamiento interactivo a barriles vanilla del mundo. Puedes:

- Abrir e inspeccionar barriles.
- Beber desde barriles con agua cuando el liquido es bebible.
- Lavarte, lavar ropa y lavar objetos compatibles usando agua del barril.
- Verter liquidos compatibles al barril.
- Llenar recipientes compatibles desde el barril.
- Mover liquido directamente entre barriles abiertos cercanos.
- Reabastecer generadores cercanos desde barriles con gasolina desde el menu del barril o desde Add Fuel del generador.
- Vaciar barriles de forma progresiva cuando necesitas limpiarlos o cambiar su contenido.
- Levantar, mover y colocar barriles abiertos conservando su contenido y peso.

El contenido del barril se revela en la primera apertura:

- Tipo de liquido: Agua, Agua Contaminada, Gasolina, Lejia o Vacio.
- Cantidad: entre 1 y 160 unidades cuando hay liquido.

Una vez generado, el estado del barril queda guardado en el mundo y compartido en multiplayer.

---

## Funciones existentes

1. **Abrir barril** con una herramienta requerida: Palanca, Palanca Forjada, Destornillador, Llave de Tuberia o Tijeras de Chapa.
2. **Inspeccionar informacion del barril** desde el menu contextual Barril: tipo de liquido, nivel, requisitos, iconos de items y razones de deshabilitado.
3. **Beber del barril** cuando contiene Agua o Agua Contaminada.
4. **Lavar desde barril**:
   - Lavado del personaje.
   - Lavado de ropa y objetos lavables del inventario.
   - Limpieza de objetos tipo vendaje compatibles cuando el agua es segura.
   - El jabon es opcional, pero afecta la velocidad/comportamiento de limpieza.
5. **Verter al barril** desde recipientes compatibles del inventario, requiere Embudo.
6. **Llenar recipientes desde el barril** usando recipientes compatibles del inventario, requiere Manguera de Goma.
7. **Transferencia barril a barril** entre barriles abiertos cercanos.
8. **Reabastecimiento de generadores** desde barriles cercanos con gasolina desde el menu del barril o desde Add Fuel del generador, requiere Manguera de Goma cuando ese requisito esta activado.
9. **Llenar todo / menu agrupado** con agrupacion de recipientes estilo vanilla.
10. **Vaciado progresivo** que drena liquido durante la accion temporizada; si se interrumpe, conserva la cantidad ya drenada.
11. **Contenido aleatorio en primera apertura** segun categoria del tile.
12. **Opciones Sandbox** para capacidad, peso vacio, distancia de interaccion, herramientas de apertura, requisitos de herramientas de transferencia y pesos de aparicion de liquidos por tipo de barril.
13. **Estado persistente del barril** que sobrevive guardados, recargas, levantar/colocar y reinicios del servidor.
14. **Comportamiento multiplayer seguro** con proteccion contra uso solapado del mismo barril.
15. **Peso dinamico del barril** segun tipo y cantidad de liquido.
16. **Soporte singleplayer y multiplayer**.
17. **Compatibilidad opcional con mods** para bidones militares de gasolina y agua de DamnLib/USMIL en transferencias de liquidos.
18. **Traducciones actuales**: Ingles, Espanol y Espanol Argentino.

### Datos de juego

| Categoria | Estado actual |
|---|---|
| Tipos de liquido | Agua, Agua Contaminada, Gasolina, Lejia, Vacio |
| Capacidad del barril | 160 unidades |
| Consumo por beber | 0.12 unidades por accion de beber |
| Costo por lavado | 1 unidad por segmento de cuerpo/item lavado |
| Tiles soportados | Barriles industriales, militares y crafteados |
| Herramientas de transferencia | Embudo para verter, Manguera de Goma para llenar recipientes y reabastecer generadores |

---

## Funcionalidades planeadas

Estas son ideas para versiones futuras, no funciones actuales:

- **Compatibilidad con Water Bidons**: permitir llenar barriles desde los recipientes del mod Water Bidons (Workshop ID: 3628782804, Mod ID: WaterBidon).
- **Hallazgos raros de liquidos**: agregar descubrimientos poco comunes, como barriles de leche o vino en comercios.
- **Etiquetas o marcadores de propiedad**: mejor organizacion en bases multiplayer.
- **Tratamiento de agua**: pasos de gameplay para volver mas segura el agua contaminada.
- **Transferencia desde agua presurizada**: usar una Manguera de Goma para mover agua desde piletas o banaderas hacia barriles antes del corte de agua, o mucho mas lento despues si se puede soportar.
- **Recolectores de lluvia y nieve**: cortar la tapa de los barriles con un soplete de propano y reciclarlos como recolectores, incluyendo nieve que se derrite en agua.
- **Logistica de gasolina**: recargar vehiculos desde barriles de gasolina.
- **Logistica de estaciones de servicio**: cargar nafta desde surtidores directo a barriles.
- **Suministro tipo caneria desde barriles**: alimentar piletas, banaderas y lavarropas desde barriles cercanos o elevados.
- **Sistema de condicion del barril**: oxido, dano, fugas, contaminacion o riesgos de confiabilidad.

---

## Compatibilidad

- **Version del juego:** Project Zomboid Build 42
- **Multiplayer:** Soportado
- **Singleplayer:** Soportado
- **Solo servidor:** No soportado; el mod tambien debe estar activo en los clientes
- **Instalacion segura:** Pensado para funcionar con partidas existentes; siempre conviene hacer backup antes de agregar o quitar mods

---

## Traducciones

Traducciones actuales:

- Ingles
- Espanol
- Espanol Argentino

La ayuda de la comunidad con traducciones es bienvenida. Si quieres ayudar a traducir Barrels Expanded a otro idioma o mejorar una traduccion existente, los aportes y sugerencias son apreciados.

---

## Instalacion

1. Suscribete al mod en Steam Workshop.
2. Activalo desde el menu **Mods** en el menu principal o al crear partida.
3. No requiere configuracion adicional.

---

*[English](README.md)*
